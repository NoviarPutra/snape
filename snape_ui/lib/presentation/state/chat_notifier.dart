import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/audio_queue_service.dart';
import '../../data/models/websocket_events.dart';
import '../../domain/models/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';
import 'chat_state.dart';
import 'providers.dart';

class ChatNotifier extends StateNotifier<ChatState> {
  final ChatRepository _repository;
  final AudioQueueService? _audioQueueService;
  StreamSubscription<WSOutputEvent>? _eventSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<bool>? _speakingSubscription;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _autoplayAudio = false;
  static const int _maxReconnectAttempts = 5;
  static const _uuid = Uuid();

  ChatNotifier(this._repository, [this._audioQueueService])
      : super(const ChatState()) {
    _listenToStreams();
  }

  bool get isAutoplayAudio => _autoplayAudio;

  void setAutoplayAudio(bool enabled) {
    _autoplayAudio = enabled;
  }

  void _listenToStreams() {
    _eventSubscription = _repository.chatEvents.listen(
      _handleWebSocketEvent,
      onError: (error) {
        state = state.copyWith(
          errorMessage: 'Stream error: $error',
          isStreaming: false,
        );
      },
    );

    _connectionSubscription = _repository.connectionStatus.listen(
      (isConnected) {
        if (isConnected) {
          _reconnectAttempts = 0;
          _reconnectTimer?.cancel();
          state = state.copyWith(
            connectionStatus: ConnectionStatus.connected,
            clearError: true,
          );
        } else {
          if (state.sessionId != null &&
              state.connectionStatus != ConnectionStatus.disconnected &&
              _reconnectAttempts < _maxReconnectAttempts) {
            _scheduleReconnect();
          } else {
            state = state.copyWith(
              connectionStatus: ConnectionStatus.disconnected,
            );
          }
        }
      },
    );

    if (_audioQueueService != null) {
      _speakingSubscription =
          _audioQueueService.isSpeakingStream.listen((speaking) {
        if (!speaking) {
          state = state.copyWith(
            isSpeaking: false,
            clearPlayingMessageId: true,
          );
        } else {
          state = state.copyWith(isSpeaking: true);
        }
      });
    }
  }

  Future<void> switchSession(String sessionId) async {
    if (state.sessionId == sessionId && state.messages.isNotEmpty) {
      return;
    }

    _audioQueueService?.stopAndClear();
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;

    state = state.copyWith(
      sessionId: sessionId,
      messages: [],
      isLoadingHistory: true,
      isStreaming: false,
      clearError: true,
      clearStreamingId: true,
      clearPlayingMessageId: true,
      clearLoadingAudioMessageId: true,
    );

    try {
      final history = await _repository.getSessionHistory(sessionId);
      state = state.copyWith(
        messages: history,
        isLoadingHistory: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingHistory: false,
        errorMessage: 'Failed to load chat history: $e',
      );
    }

    await _connectWebSocket(sessionId);
  }

  Future<void> _connectWebSocket(String sessionId) async {
    state = state.copyWith(connectionStatus: ConnectionStatus.connecting);
    try {
      await _repository.connectToChatStream(sessionId);
      state = state.copyWith(
        connectionStatus: ConnectionStatus.connected,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        connectionStatus: ConnectionStatus.disconnected,
        errorMessage: 'Unable to connect to live stream: $e',
      );
    }
  }

  void _scheduleReconnect() {
    _reconnectAttempts++;
    state = state.copyWith(connectionStatus: ConnectionStatus.reconnecting);
    _reconnectTimer?.cancel();

    final backoffSeconds = _reconnectAttempts * 2;
    _reconnectTimer = Timer(Duration(seconds: backoffSeconds), () async {
      if (state.sessionId != null) {
        await _connectWebSocket(state.sessionId!);
      }
    });
  }

  Future<void> retryConnection() async {
    if (state.sessionId != null) {
      _reconnectAttempts = 0;
      await _connectWebSocket(state.sessionId!);
    }
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.sessionId == null) return;

    // Deduplicate: ignore identical message if currently streaming the same input
    if (state.isStreaming &&
        state.messages.isNotEmpty &&
        state.messages.any((m) => m.isUser && m.content == trimmed)) {
      return;
    }

    // Barge-in: halt ongoing companion audio playback and clear queued audio buffers
    _audioQueueService?.stopAndClear();

    // Sanitize any previous unresolved streaming placeholders to prevent stuck loading bubbles
    final sanitizedMessages = state.messages.map((m) {
      if (m.isStreaming) {
        return m.copyWith(
          isStreaming: false,
          status: m.content.isEmpty ? MessageStatus.error : MessageStatus.delivered,
          content: m.content.isEmpty
              ? 'Response was interrupted. Please send again.'
              : m.content,
        );
      }
      return m;
    }).toList();

    final userMessageId = _uuid.v4();
    final userMessage = ChatMessage(
      id: userMessageId,
      sessionId: state.sessionId!,
      role: MessageRole.user,
      content: trimmed,
      createdAt: DateTime.now(),
      status: MessageStatus.delivered,
    );

    final streamingAssistantId = _uuid.v4();
    final assistantPlaceholder = ChatMessage(
      id: streamingAssistantId,
      sessionId: state.sessionId!,
      role: MessageRole.assistant,
      content: '',
      createdAt: DateTime.now(),
      isStreaming: true,
      status: MessageStatus.streaming,
    );

    final updatedMessages = [
      ...sanitizedMessages,
      userMessage,
      assistantPlaceholder,
    ];

    state = state.copyWith(
      messages: updatedMessages,
      isStreaming: true,
      currentStreamingId: streamingAssistantId,
      clearError: true,
      clearPlayingMessageId: true,
      clearLoadingAudioMessageId: true,
    );

    try {
      _repository.sendChatMessage(trimmed);
    } catch (e) {
      final listWithError = state.messages.map((m) {
        if (m.id == streamingAssistantId) {
          return m.copyWith(
            content: 'Failed to send message: $e',
            isStreaming: false,
            status: MessageStatus.error,
          );
        }
        return m;
      }).toList();

      state = state.copyWith(
        messages: listWithError,
        isStreaming: false,
        clearStreamingId: true,
        errorMessage: 'Failed to send: $e',
      );
    }
  }

  void _handleWebSocketEvent(WSOutputEvent event) {
    switch (event) {
      case WSTokenEvent(:final content):
        _onTokenReceived(content);
      case WSAudioEvent(:final audioBase64, :final sentence):
        _onAudioReceived(audioBase64, sentence: sentence);
      case WSDoneEvent(
          :final fullText,
          :final userMessageId,
          :final assistantMessageId,
          :final extractedMemories
        ):
        _onStreamDone(
          fullText: fullText,
          userMessageId: userMessageId,
          assistantMessageId: assistantMessageId,
          extractedMemories: extractedMemories,
        );
      case WSErrorEvent(:final message):
        state = state.copyWith(
          errorMessage: message,
          isStreaming: false,
        );
      case WSPongEvent():
        break;
      case WSUnknownEvent():
        break;
    }
  }

  void _onAudioReceived(String audioBase64, {String? sentence}) {
    if (audioBase64.trim().isEmpty) return;
    try {
      final cleaned = audioBase64.replaceAll(RegExp(r'\s+'), '');
      final bytes = base64Decode(cleaned);

      if (state.currentStreamingId.isNotEmpty) {
        final currentChunks = state.audioBuffers[state.currentStreamingId] ?? [];
        final newBuffers = Map<String, List<Uint8List>>.from(state.audioBuffers);
        newBuffers[state.currentStreamingId] = [...currentChunks, bytes];
        state = state.copyWith(audioBuffers: newBuffers);
      }

      if (_autoplayAudio) {
        _audioQueueService?.enqueueBytes(bytes);
      }
    } catch (e) {
      // Ignore base64 audio decoding errors gracefully
    }
  }

  void _onTokenReceived(String token) {
    if (state.currentStreamingId.isEmpty) return;

    final updatedMessages = state.messages.map((msg) {
      if (msg.id == state.currentStreamingId) {
        return msg.copyWith(
          content: msg.content + token,
          isStreaming: true,
          status: MessageStatus.streaming,
        );
      }
      return msg;
    }).toList();

    state = state.copyWith(
      messages: updatedMessages,
      isStreaming: true,
    );
  }

  void _onStreamDone({
    required String fullText,
    String? userMessageId,
    String? assistantMessageId,
    List<String> extractedMemories = const [],
  }) {
    final targetId = assistantMessageId ?? state.currentStreamingId;
    final newBuffers = Map<String, List<Uint8List>>.from(state.audioBuffers);

    if (state.currentStreamingId.isNotEmpty &&
        targetId.isNotEmpty &&
        state.currentStreamingId != targetId &&
        newBuffers.containsKey(state.currentStreamingId)) {
      final buffer = newBuffers.remove(state.currentStreamingId);
      if (buffer != null) {
        newBuffers[targetId] = buffer;
      }
    }

    final updatedMessages = state.messages.map((msg) {
      if (msg.id == state.currentStreamingId) {
        return msg.copyWith(
          id: assistantMessageId ?? msg.id,
          content: fullText.isNotEmpty ? fullText : msg.content,
          isStreaming: false,
          status: MessageStatus.delivered,
          extractedMemories: extractedMemories,
        );
      }
      return msg;
    }).toList();

    state = state.copyWith(
      messages: updatedMessages,
      isStreaming: false,
      clearStreamingId: true,
      lastExtractedMemories: extractedMemories,
      audioBuffers: newBuffers,
    );
  }

  Future<void> playMessageAudio(String messageId, String content) async {
    if (state.playingMessageId == messageId && state.isSpeaking) {
      stopAudio();
      return;
    }

    _audioQueueService?.stopAndClear();

    final cachedChunks = state.audioBuffers[messageId];
    if (cachedChunks != null && cachedChunks.isNotEmpty) {
      state = state.copyWith(
        playingMessageId: messageId,
        clearLoadingAudioMessageId: true,
      );
      for (final chunk in cachedChunks) {
        _audioQueueService?.enqueueBytes(chunk);
      }
      return;
    }

    final trimmed = content.trim();
    if (trimmed.isEmpty) return;

    state = state.copyWith(
      loadingAudioMessageId: messageId,
      clearPlayingMessageId: true,
    );

    try {
      final audioBytes = await _repository.synthesizeAudio(trimmed);
      final newBuffers = Map<String, List<Uint8List>>.from(state.audioBuffers);
      newBuffers[messageId] = [audioBytes];

      state = state.copyWith(
        clearLoadingAudioMessageId: true,
        playingMessageId: messageId,
        audioBuffers: newBuffers,
      );

      _audioQueueService?.enqueueBytes(audioBytes);
    } catch (e) {
      state = state.copyWith(
        clearLoadingAudioMessageId: true,
        errorMessage: 'Failed to play audio: $e',
      );
    }
  }

  void stopAudio() {
    _audioQueueService?.stopAndClear();
    state = state.copyWith(clearPlayingMessageId: true);
  }

  @override
  void dispose() {
    _speakingSubscription?.cancel();
    _reconnectTimer?.cancel();
    _eventSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final repository = ref.watch(chatRepositoryProvider);
  final audioQueue = ref.watch(audioQueueServiceProvider);
  return ChatNotifier(repository, audioQueue);
});
