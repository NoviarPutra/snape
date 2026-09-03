import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:snape_ui/core/services/audio_queue_service.dart';
import 'package:snape_ui/data/models/websocket_events.dart';
import 'package:snape_ui/domain/models/chat_message.dart';
import 'package:snape_ui/domain/models/session.dart';
import 'package:snape_ui/domain/repositories/chat_repository.dart';
import 'package:snape_ui/presentation/state/chat_notifier.dart';
import 'package:snape_ui/presentation/state/chat_state.dart';

class FakeChatRepository implements ChatRepository {
  final _eventController = StreamController<WSOutputEvent>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final List<String> sentMessages = [];
  bool connected = false;
  List<ChatMessage> mockHistory = [];

  @override
  Future<List<SessionModel>> getSessions({String? spaceSlug}) async {
    return [
      SessionModel(
        id: 'sess-1',
        title: 'Session 1',
        spaceSlug: spaceSlug ?? 'english_b2',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      )
    ];
  }

  @override
  Future<SessionModel> createSession({
    String title = 'Casual English Chat',
    String spaceSlug = 'english_b2',
  }) async {
    return SessionModel(
      id: 'sess-2',
      title: title,
      spaceSlug: spaceSlug,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<List<ChatMessage>> getSessionHistory(String sessionId) async {
    return mockHistory;
  }

  @override
  Future<void> deleteSession(String sessionId) async {}

  @override
  Future<Uint8List> synthesizeAudio(String text) async {
    return Uint8List.fromList([1, 2, 3, 4]);
  }

  @override
  Future<void> connectToChatStream(String sessionId) async {
    connected = true;
    _connectionController.add(true);
  }

  @override
  void sendChatMessage(String content) {
    sentMessages.add(content);
  }

  @override
  Stream<WSOutputEvent> get chatEvents => _eventController.stream;

  @override
  Stream<bool> get connectionStatus => _connectionController.stream;

  @override
  bool get isConnected => connected;

  @override
  Future<void> disconnectStream() async {
    connected = false;
    _connectionController.add(false);
  }

  void emitEvent(WSOutputEvent event) {
    _eventController.add(event);
  }

  void emitConnectionStatus(bool isConnected) {
    connected = isConnected;
    _connectionController.add(isConnected);
  }

  @override
  void dispose() {
    _eventController.close();
    _connectionController.close();
  }
}

class FakeAudioPlayerAdapter implements AudioPlayerAdapter {
  final _completeController = StreamController<void>.broadcast();
  final List<Uint8List> playedChunks = [];
  bool isStopped = false;

  @override
  Stream<void> get onPlayerComplete => _completeController.stream;

  @override
  Future<void> playBytes(Uint8List bytes, {String? mimeType}) async {
    isStopped = false;
    playedChunks.add(bytes);
  }

  @override
  Future<void> stop() async {
    isStopped = true;
  }

  @override
  Future<void> dispose() async {
    await _completeController.close();
  }

  void complete() {
    _completeController.add(null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatNotifier State Management', () {
    late FakeChatRepository repository;
    late FakeAudioPlayerAdapter audioAdapter;
    late AudioQueueService audioService;
    late ChatNotifier notifier;

    setUp(() {
      repository = FakeChatRepository();
      audioAdapter = FakeAudioPlayerAdapter();
      audioService = AudioQueueService(playerAdapter: audioAdapter);
      notifier = ChatNotifier(repository, audioService);
    });

    tearDown(() {
      notifier.dispose();
      repository.dispose();
      audioService.dispose();
    });

    test('initial state is disconnected with empty messages', () {
      expect(notifier.state.connectionStatus, ConnectionStatus.disconnected);
      expect(notifier.state.messages, isEmpty);
      expect(notifier.state.sessionId, isNull);
    });

    test('switchSession loads history and connects to websocket stream', () async {
      final mockMessages = [
        ChatMessage(
          id: 'msg-1',
          sessionId: 'sess-1',
          role: MessageRole.user,
          content: 'Hello',
          createdAt: DateTime.now(),
        ),
        ChatMessage(
          id: 'msg-2',
          sessionId: 'sess-1',
          role: MessageRole.assistant,
          content: 'Hi there!',
          createdAt: DateTime.now(),
        ),
      ];
      repository.mockHistory = mockMessages;

      await notifier.switchSession('sess-1');

      expect(notifier.state.sessionId, 'sess-1');
      expect(notifier.state.messages.length, 2);
      expect(notifier.state.isLoadingHistory, isFalse);
      expect(notifier.state.connectionStatus, ConnectionStatus.connected);
    });

    test('sendMessage creates user message and streaming assistant placeholder', () async {
      await notifier.switchSession('sess-1');
      await notifier.sendMessage('How are you?');

      expect(notifier.state.messages.length, 2);
      final userMsg = notifier.state.messages[0];
      expect(userMsg.isUser, isTrue);
      expect(userMsg.content, 'How are you?');

      final assistantMsg = notifier.state.messages[1];
      expect(assistantMsg.isAssistant, isTrue);
      expect(assistantMsg.isStreaming, isTrue);
      expect(notifier.state.isStreaming, isTrue);
    });

    test('token stream updates accumulating text content', () async {
      await notifier.switchSession('sess-1');
      await notifier.sendMessage('How are you?');

      repository.emitEvent(const WSTokenEvent(content: 'I '));
      repository.emitEvent(const WSTokenEvent(content: 'am '));
      repository.emitEvent(const WSTokenEvent(content: 'great!'));

      // Allow event stream to process
      await Future<void>.delayed(Duration.zero);

      final assistantMsg = notifier.state.messages[1];
      expect(assistantMsg.content, 'I am great!');
      expect(assistantMsg.isStreaming, isTrue);
      expect(notifier.state.isStreaming, isTrue);
    });

    test('audio event buffers audio in memory and does not autoplay in text chat mode', () async {
      await notifier.switchSession('sess-1');
      await notifier.sendMessage('Hello');
      final streamingId = notifier.state.currentStreamingId;
      final dummyAudio = base64Encode(Uint8List.fromList([1, 2, 3, 4]));

      repository.emitEvent(WSAudioEvent(
        sentence: 'Hello there',
        audioBase64: dummyAudio,
      ));
      await Future<void>.delayed(Duration.zero);

      // In text chat mode, audio is buffered for on-demand playback, not sent directly to speaker
      expect(audioAdapter.playedChunks.length, 0);
      expect(notifier.state.audioBuffers.containsKey(streamingId), isTrue);
      expect(notifier.state.audioBuffers[streamingId]!.length, 1);
    });

    test('audio event autoplays when autoplayAudio is enabled (Voice Call mode)', () async {
      await notifier.switchSession('sess-1');
      notifier.setAutoplayAudio(true);
      final dummyAudio = base64Encode(Uint8List.fromList([1, 2, 3, 4]));

      repository.emitEvent(WSAudioEvent(
        sentence: 'Hello there',
        audioBase64: dummyAudio,
      ));
      await Future<void>.delayed(Duration.zero);

      expect(audioAdapter.playedChunks.length, 1);
      expect(notifier.state.isSpeaking, isTrue);

      audioAdapter.complete();
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.isSpeaking, isFalse);
    });

    test('playMessageAudio plays from buffered audio if available', () async {
      await notifier.switchSession('sess-1');
      await notifier.sendMessage('Hello');
      final dummyAudio = base64Encode(Uint8List.fromList([5, 6, 7, 8]));

      repository.emitEvent(WSAudioEvent(
        sentence: 'Hello there',
        audioBase64: dummyAudio,
      ));
      repository.emitEvent(WSDoneEvent(
        sessionId: 'sess-1',
        fullText: 'Hello there',
        assistantMessageId: 'asst-msg-123',
      ));
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.audioBuffers.containsKey('asst-msg-123'), isTrue);

      await notifier.playMessageAudio('asst-msg-123', 'Hello there');

      expect(audioAdapter.playedChunks.length, 1);
      expect(notifier.state.playingMessageId, 'asst-msg-123');
      expect(notifier.state.isSpeaking, isTrue);
    });

    test('playMessageAudio synthesizes on-demand from API for unbuffered historical message', () async {
      await notifier.switchSession('sess-1');

      await notifier.playMessageAudio('historical-msg-1', 'This is a historical message');

      expect(audioAdapter.playedChunks.length, 1);
      expect(notifier.state.playingMessageId, 'historical-msg-1');
      expect(notifier.state.audioBuffers.containsKey('historical-msg-1'), isTrue);
    });

    test('stopAudio halts playback and resets playingMessageId', () async {
      await notifier.switchSession('sess-1');
      await notifier.playMessageAudio('msg-1', 'Some message');

      expect(notifier.state.playingMessageId, 'msg-1');

      notifier.stopAudio();

      expect(audioAdapter.isStopped, isTrue);
      expect(notifier.state.playingMessageId, isNull);
    });

    test('barge-in: sending new message stops playing audio', () async {
      await notifier.switchSession('sess-1');
      await notifier.playMessageAudio('msg-1', 'Some message');
      expect(notifier.state.playingMessageId, 'msg-1');

      // Barge in with new message
      await notifier.sendMessage('Interrupting with new question!');

      expect(audioAdapter.isStopped, isTrue);
      expect(notifier.state.playingMessageId, isNull);
    });

    test('done event finalizes assistant message with extracted memories and sets isStreaming to false', () async {
      await notifier.switchSession('sess-1');
      await notifier.sendMessage('How are you?');

      repository.emitEvent(const WSTokenEvent(content: 'I am '));
      repository.emitEvent(const WSDoneEvent(
        sessionId: 'sess-1',
        fullText: 'I am great, thank you!',
        extractedMemories: ['User is friendly and studying IELTS'],
      ));

      await Future<void>.delayed(Duration.zero);

      final assistantMsg = notifier.state.messages[1];
      expect(assistantMsg.content, 'I am great, thank you!');
      expect(assistantMsg.isStreaming, isFalse);
      expect(assistantMsg.extractedMemories, ['User is friendly and studying IELTS']);
      expect(notifier.state.isStreaming, isFalse);
      expect(notifier.state.lastExtractedMemories, ['User is friendly and studying IELTS']);
    });

    test('sendMessage sanitizes prior streaming message so bubble is not stuck loading', () async {
      await notifier.switchSession('sess-1');
      await notifier.sendMessage('First turn');

      expect(notifier.state.messages[1].isStreaming, isTrue);

      // Send second message before first is resolved
      await notifier.sendMessage('Second turn');

      expect(notifier.state.messages[1].isStreaming, isFalse);
      expect(notifier.state.messages[1].content, 'Response was interrupted. Please send again.');
      expect(notifier.state.messages[3].isStreaming, isTrue);
    });

    test('sendMessage drops identical duplicate message when streaming is active', () async {
      await notifier.switchSession('sess-1');
      await notifier.sendMessage('Duplicate prompt');

      expect(repository.sentMessages.length, 1);

      // Send duplicate
      await notifier.sendMessage('Duplicate prompt');
      expect(repository.sentMessages.length, 1);
    });
  });
}
