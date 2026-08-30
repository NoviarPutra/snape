import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/websocket_events.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/models/chat_message.dart';
import 'chat_state.dart';
import 'session_notifier.dart';

class ChatNotifier extends StateNotifier<ChatState> {
  final ChatRepository _repository;
  StreamSubscription<WSOutputEvent>? _eventSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const _uuid = Uuid();

  ChatNotifier(this._repository) : super(const ChatState()) {
    _listenToStreams();
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
  }

  Future<void> switchSession(String sessionId) async {
    if (state.sessionId == sessionId && state.messages.isNotEmpty) {
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;

    state = state.copyWith(
      sessionId: sessionId,
      messages: [],
      isLoadingHistory: true,
      isStreaming: false,
      clearError: true,
      clearStreamingId: true,
    );

    // 1. Fetch History from REST
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

    // 2. Connect WebSocket
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
      ...state.messages,
      userMessage,
      assistantPlaceholder,
    ];

    state = state.copyWith(
      messages: updatedMessages,
      isStreaming: true,
      currentStreamingId: streamingAssistantId,
      clearError: true,
    );

    try {
      _repository.sendChatMessage(trimmed);
    } catch (e) {
      // Mark assistant placeholder as error
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
      case WSAudioEvent():
        // Audio chunk received (will be handled by TTS audio player in issue 06)
        break;
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
    final updatedMessages = state.messages.map((msg) {
      if (msg.id == state.currentStreamingId) {
        return msg.copyWith(
          id: assistantMessageId ?? msg.id,
          content: fullText.isNotEmpty ? fullText : msg.content,
          isStreaming: false,
          status: MessageStatus.delivered,
        );
      }
      return msg;
    }).toList();

    state = state.copyWith(
      messages: updatedMessages,
      isStreaming: false,
      clearStreamingId: true,
      lastExtractedMemories: extractedMemories,
    );
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _eventSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final repository = ref.watch(chatRepositoryProvider);
  return ChatNotifier(repository);
});
