import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:snape_ui/data/models/websocket_events.dart';
import 'package:snape_ui/domain/models/chat_message.dart';
import 'package:snape_ui/domain/models/session.dart';
import 'package:snape_ui/domain/repositories/chat_repository.dart';
import 'package:snape_ui/presentation/state/session_notifier.dart';

class MockChatRepository implements ChatRepository {
  List<SessionModel> sessions = [];
  String? lastGetSessionsSpaceSlug;
  String? lastCreateSessionSpaceSlug;
  String? lastCreateSessionTitle;
  bool shouldThrow = false;

  @override
  Future<List<SessionModel>> getSessions({String? spaceSlug}) async {
    if (shouldThrow) {
      throw Exception('Failed to get sessions');
    }
    lastGetSessionsSpaceSlug = spaceSlug;
    if (spaceSlug != null) {
      return sessions.where((s) => s.spaceSlug == spaceSlug).toList();
    }
    return sessions;
  }

  @override
  Future<SessionModel> createSession({
    String title = 'Casual English Chat',
    String spaceSlug = 'english_b2',
  }) async {
    if (shouldThrow) {
      throw Exception('Failed to create session');
    }
    lastCreateSessionTitle = title;
    lastCreateSessionSpaceSlug = spaceSlug;
    final newSession = SessionModel(
      id: 'sess-${sessions.length + 1}',
      title: title,
      spaceSlug: spaceSlug,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    sessions.insert(0, newSession);
    return newSession;
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    sessions.removeWhere((s) => s.id == sessionId);
  }

  @override
  Future<List<ChatMessage>> getSessionHistory(String sessionId) async => [];

  @override
  Future<Uint8List> synthesizeAudio(String text) async => Uint8List(0);

  @override
  Future<void> connectToChatStream(String sessionId) async {}

  @override
  void sendChatMessage(String content) {}

  @override
  Stream<WSOutputEvent> get chatEvents => const Stream.empty();

  @override
  Stream<bool> get connectionStatus => Stream.value(true);

  @override
  bool get isConnected => true;

  @override
  Future<void> disconnectStream() async {}

  @override
  void dispose() {}
}

void main() {
  group('SessionNotifier with spaceSlug', () {
    late MockChatRepository repository;
    late SessionNotifier notifier;

    setUp(() {
      repository = MockChatRepository();
      repository.sessions = [
        SessionModel(
          id: 'sess-1',
          title: 'Session 1',
          spaceSlug: 'english_b2',
          createdAt: DateTime(2026, 9, 1),
          updatedAt: DateTime(2026, 9, 1),
        ),
        SessionModel(
          id: 'sess-2',
          title: 'Session 2',
          spaceSlug: 'tech',
          createdAt: DateTime(2026, 9, 2),
          updatedAt: DateTime(2026, 9, 2),
        ),
      ];
      notifier = SessionNotifier(repository);
    });

    test('loadSessions passes spaceSlug filter to repository', () async {
      await notifier.loadSessions(spaceSlug: 'tech');

      expect(repository.lastGetSessionsSpaceSlug, 'tech');
      expect(notifier.state.sessions.length, 1);
      expect(notifier.state.sessions.first.id, 'sess-2');
      expect(notifier.state.currentSession?.id, 'sess-2');
    });

    test('createSession passes spaceSlug to repository', () async {
      final newSession = await notifier.createSession(
        title: 'Tech discussion',
        spaceSlug: 'tech',
      );

      expect(repository.lastCreateSessionTitle, 'Tech discussion');
      expect(repository.lastCreateSessionSpaceSlug, 'tech');
      expect(newSession?.spaceSlug, 'tech');
      expect(notifier.state.currentSession?.spaceSlug, 'tech');
      expect(notifier.state.sessions.first.spaceSlug, 'tech');
    });
  });
}
