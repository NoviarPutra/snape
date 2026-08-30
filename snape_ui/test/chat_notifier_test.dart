import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
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
  Future<List<SessionModel>> getSessions() async {
    return [
      SessionModel(
        id: 'sess-1',
        title: 'Session 1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      )
    ];
  }

  @override
  Future<SessionModel> createSession({String title = 'Casual English Chat'}) async {
    return SessionModel(
      id: 'sess-2',
      title: title,
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

  void emitConnection(bool isConnected) {
    connected = isConnected;
    _connectionController.add(isConnected);
  }

  @override
  void dispose() {
    _eventController.close();
    _connectionController.close();
  }
}

void main() {
  group('ChatNotifier State Management', () {
    late FakeChatRepository repository;
    late ChatNotifier notifier;

    setUp(() {
      repository = FakeChatRepository();
      notifier = ChatNotifier(repository);
    });

    tearDown(() {
      notifier.dispose();
      repository.dispose();
    });

    test('initial state is disconnected with empty messages', () {
      expect(notifier.state.messages, isEmpty);
      expect(notifier.state.connectionStatus, ConnectionStatus.disconnected);
    });

    test('switchSession loads history and connects to websocket stream', () async {
      repository.mockHistory = [
        ChatMessage(
          id: 'hist-1',
          sessionId: 'sess-1',
          role: MessageRole.user,
          content: 'Previous conversation',
          createdAt: DateTime.now(),
        ),
      ];

      await notifier.switchSession('sess-1');

      expect(notifier.state.sessionId, 'sess-1');
      expect(notifier.state.messages.length, 1);
      expect(notifier.state.messages.first.content, 'Previous conversation');
      expect(notifier.state.connectionStatus, ConnectionStatus.connected);
    });

    test('sendMessage creates user message and streaming assistant placeholder', () async {
      await notifier.switchSession('sess-1');
      await notifier.sendMessage('Hello Snape!');

      expect(repository.sentMessages, contains('Hello Snape!'));
      expect(notifier.state.messages.length, 2);
      expect(notifier.state.messages[0].isUser, isTrue);
      expect(notifier.state.messages[0].content, 'Hello Snape!');

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

    test('done event finalizes assistant message and sets isStreaming to false', () async {
      await notifier.switchSession('sess-1');
      await notifier.sendMessage('How are you?');

      repository.emitEvent(const WSTokenEvent(content: 'I am '));
      repository.emitEvent(const WSDoneEvent(
        sessionId: 'sess-1',
        fullText: 'I am great, thank you!',
        extractedMemories: ['User is friendly'],
      ));

      await Future<void>.delayed(Duration.zero);

      final assistantMsg = notifier.state.messages[1];
      expect(assistantMsg.content, 'I am great, thank you!');
      expect(assistantMsg.isStreaming, isFalse);
      expect(notifier.state.isStreaming, isFalse);
      expect(notifier.state.lastExtractedMemories, ['User is friendly']);
    });
  });
}
