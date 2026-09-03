import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snape_ui/core/services/speech_service.dart';
import 'package:snape_ui/core/theme/app_theme.dart';
import 'package:snape_ui/data/models/websocket_events.dart';
import 'package:snape_ui/domain/models/chat_message.dart';
import 'package:snape_ui/domain/models/memory_item.dart';
import 'package:snape_ui/domain/models/session.dart';
import 'package:snape_ui/domain/models/space.dart';
import 'package:snape_ui/domain/repositories/chat_repository.dart';
import 'package:snape_ui/domain/repositories/memory_repository.dart';
import 'package:snape_ui/presentation/screens/chat_screen.dart';
import 'package:snape_ui/presentation/screens/session_list_screen.dart';
import 'package:snape_ui/presentation/state/providers.dart';

class FakeChatRepository implements ChatRepository {
  List<SessionModel> sessions = [];
  bool createdCalled = false;
  String? lastCreatedSpaceSlug;
  String? lastCreatedTitle;
  String? deletedSessionId;

  final StreamController<WSOutputEvent> _eventController =
      StreamController<WSOutputEvent>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  @override
  Future<List<SessionModel>> getSessions({String? spaceSlug}) async {
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
    createdCalled = true;
    lastCreatedSpaceSlug = spaceSlug;
    lastCreatedTitle = title;
    final session = SessionModel(
      id: 'new_session_id',
      title: title,
      spaceSlug: spaceSlug,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    sessions.insert(0, session);
    return session;
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    deletedSessionId = sessionId;
    sessions.removeWhere((s) => s.id == sessionId);
  }

  @override
  Future<SessionModel> updateSessionTitle(String sessionId, String title) async {
    final index = sessions.indexWhere((s) => s.id == sessionId);
    if (index == -1) {
      throw Exception('Session not found');
    }
    final updated = sessions[index].copyWith(title: title, updatedAt: DateTime.now());
    sessions[index] = updated;
    return updated;
  }

  @override
  Future<List<ChatMessage>> getSessionHistory(String sessionId) async => [];

  @override
  Future<Uint8List> synthesizeAudio(String text) async => Uint8List(0);

  @override
  Future<void> connectToChatStream(String sessionId) async {
    _connectionController.add(true);
  }

  @override
  void sendChatMessage(String content) {}

  @override
  Stream<WSOutputEvent> get chatEvents => _eventController.stream;

  @override
  Stream<bool> get connectionStatus => _connectionController.stream;

  @override
  bool get isConnected => true;

  @override
  Future<void> disconnectStream() async {
    _connectionController.add(false);
  }

  @override
  Future<void> dispose() async {
    await _eventController.close();
    await _connectionController.close();
  }
}

class FakeSpeechService implements BaseSpeechService {
  @override
  bool get isAvailable => false;
  @override
  bool get isListening => false;
  @override
  Future<bool> initialize() async => false;
  @override
  Future<void> startListening({
    required Function(String text, bool isFinal) onResult,
    Function(bool isListening)? onListeningStateChanged,
    String localeId = 'id_ID',
  }) async {}
  @override
  Future<void> stopListening() async {}
  void dispose() {}
}

class FakeMemoryRepository implements MemoryRepository {
  @override
  Future<List<MemoryItem>> getMemories(
          {int limit = 50, int offset = 0, String? category}) async =>
      [];
  @override
  Future<void> deleteMemory(String memoryId) async {}
}

Widget createSessionListTestApp({
  required FakeChatRepository chatRepo,
  required SpaceModel space,
}) {
  return ProviderScope(
    overrides: [
      chatRepositoryProvider.overrideWithValue(chatRepo),
      speechServiceProvider.overrideWithValue(FakeSpeechService()),
      memoryRepositoryProvider.overrideWithValue(FakeMemoryRepository()),
    ],
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, child) => MaterialApp(
        theme: AppTheme.lightTheme,
        home: SessionListScreen(space: space),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testSpace = SpaceModel(
    slug: 'tech',
    displayName: 'Teknologi',
    cefrLevel: null,
    voiceCallEnabled: false,
    ttsEnabled: false,
  );

  testWidgets('SessionListScreen displays sessions for given space',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final chatRepo = FakeChatRepository()
      ..sessions = [
        SessionModel(
          id: 's1',
          title: 'System Architecture Discussion',
          spaceSlug: 'tech',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        SessionModel(
          id: 's2',
          title: 'English B2 Practice',
          spaceSlug: 'english_b2',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

    await tester.pumpWidget(
      createSessionListTestApp(chatRepo: chatRepo, space: testSpace),
    );
    await tester.pumpAndSettle();

    expect(find.text('System Architecture Discussion'), findsOneWidget);
    expect(find.text('English B2 Practice'), findsNothing);
  });

  testWidgets('SessionListScreen displays empty state when no sessions exist',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final chatRepo = FakeChatRepository()..sessions = [];

    await tester.pumpWidget(
      createSessionListTestApp(chatRepo: chatRepo, space: testSpace),
    );
    await tester.pumpAndSettle();

    expect(find.text('No Sessions Yet'), findsOneWidget);
    expect(find.text('Start Conversation'), findsOneWidget);
  });

  testWidgets(
      'Tapping New Session creates session for current space and navigates to ChatScreen',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final chatRepo = FakeChatRepository()..sessions = [];

    await tester.pumpWidget(
      createSessionListTestApp(chatRepo: chatRepo, space: testSpace),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start Conversation'));
    await tester.pumpAndSettle();

    expect(chatRepo.createdCalled, isTrue);
    expect(chatRepo.lastCreatedSpaceSlug, 'tech');
    expect(find.byType(ChatScreen), findsOneWidget);
  });

  testWidgets(
      'Tapping existing session opens ChatScreen', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final chatRepo = FakeChatRepository()
      ..sessions = [
        SessionModel(
          id: 's1',
          title: 'System Architecture Discussion',
          spaceSlug: 'tech',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

    await tester.pumpWidget(
      createSessionListTestApp(chatRepo: chatRepo, space: testSpace),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('System Architecture Discussion'));
    await tester.pumpAndSettle();

    expect(find.byType(ChatScreen), findsOneWidget);
  });

  testWidgets('Tapping delete session deletes the session', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final chatRepo = FakeChatRepository()
      ..sessions = [
        SessionModel(
          id: 's1',
          title: 'System Architecture Discussion',
          spaceSlug: 'tech',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

    await tester.pumpWidget(
      createSessionListTestApp(chatRepo: chatRepo, space: testSpace),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();

    expect(chatRepo.deletedSessionId, 's1');
  });

  testWidgets('Tapping rename icon opens RenameSessionDialog and saves updated title',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final chatRepo = FakeChatRepository()
      ..sessions = [
        SessionModel(
          id: 's1',
          title: 'Initial Tech Session',
          spaceSlug: 'tech',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

    await tester.pumpWidget(
      createSessionListTestApp(chatRepo: chatRepo, space: testSpace),
    );
    await tester.pumpAndSettle();

    expect(find.text('Initial Tech Session'), findsOneWidget);

    // Tap the rename icon
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Rename Session'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    // Enter new session title
    await tester.enterText(find.byType(TextField), 'Updated Backend Discussion');
    await tester.pumpAndSettle();

    // Tap Save button
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Rename Session'), findsNothing);
    expect(find.text('Updated Backend Discussion'), findsOneWidget);
    expect(chatRepo.sessions.first.title, 'Updated Backend Discussion');
  });
}
