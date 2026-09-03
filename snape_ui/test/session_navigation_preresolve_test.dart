import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snape_ui/core/services/speech_service.dart';
import 'package:snape_ui/core/theme/app_theme.dart';
import 'package:snape_ui/data/models/websocket_events.dart';
import 'package:snape_ui/domain/models/chat_message.dart';
import 'package:snape_ui/domain/models/memory_item.dart';
import 'package:snape_ui/domain/models/session.dart';
import 'package:snape_ui/domain/models/space.dart';
import 'package:snape_ui/domain/models/user.dart';
import 'package:snape_ui/domain/repositories/chat_repository.dart';
import 'package:snape_ui/domain/repositories/memory_repository.dart';
import 'package:snape_ui/domain/repositories/space_repository.dart';
import 'package:snape_ui/domain/repositories/user_repository.dart';
import 'package:snape_ui/presentation/screens/chat_screen.dart';
import 'package:snape_ui/presentation/screens/level_picker_screen.dart';
import 'package:snape_ui/presentation/screens/lobby_screen.dart';
import 'package:snape_ui/presentation/screens/session_list_screen.dart';
import 'package:snape_ui/presentation/widgets/session_list_item.dart';
import 'package:snape_ui/presentation/state/providers.dart';

class FakeFullChatRepo implements ChatRepository {
  List<SessionModel> sessions = [];
  int createSessionCallCount = 0;
  int getSessionsCallCount = 0;
  String? connectedSessionId;

  final StreamController<WSOutputEvent> _eventController =
      StreamController<WSOutputEvent>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  @override
  Future<List<SessionModel>> getSessions({String? spaceSlug}) async {
    getSessionsCallCount++;
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
    createSessionCallCount++;
    final session = SessionModel(
      id: 'session_${sessions.length + 1}',
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
    sessions.removeWhere((s) => s.id == sessionId);
  }

  @override
  Future<SessionModel> updateSessionTitle(
      String sessionId, String title) async {
    final index = sessions.indexWhere((s) => s.id == sessionId);
    if (index == -1) throw Exception('Not found');
    final updated = sessions[index].copyWith(title: title);
    sessions[index] = updated;
    return updated;
  }

  @override
  Future<List<ChatMessage>> getSessionHistory(String sessionId) async => [];

  @override
  Future<Uint8List> synthesizeAudio(String text) async => Uint8List(0);

  @override
  Future<void> connectToChatStream(String sessionId) async {
    connectedSessionId = sessionId;
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

class FakeSpaceRepo implements SpaceRepository {
  final List<SpaceModel> spaces;
  FakeSpaceRepo(this.spaces);

  @override
  Future<List<SpaceModel>> getSpaces() async => spaces;
}

class FakeUserRepo implements UserRepository {
  @override
  Future<UserModel> getUserProfile() async => const UserModel(
        id: 'user_1',
        username: 'Learner',
        englishLevel: 'B2',
      );
}

class FakeSpeechService extends SpeechService {
  @override
  Future<bool> initialize() async => false;
}

class FakeMemoryRepo implements MemoryRepository {
  @override
  Future<List<MemoryItem>> getMemories({
    String? category,
    int limit = 50,
    int offset = 0,
  }) async =>
      [];
  @override
  Future<void> deleteMemory(String memoryId) async {}
}

Widget createTestApp({
  required FakeFullChatRepo chatRepo,
  required List<SpaceModel> spaces,
  Widget? home,
}) {
  return ProviderScope(
    overrides: [
      chatRepositoryProvider.overrideWithValue(chatRepo),
      spaceRepositoryProvider.overrideWithValue(FakeSpaceRepo(spaces)),
      userRepositoryProvider.overrideWithValue(FakeUserRepo()),
      speechServiceProvider.overrideWithValue(FakeSpeechService()),
      memoryRepositoryProvider.overrideWithValue(FakeMemoryRepo()),
    ],
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, child) => MaterialApp(
        theme: AppTheme.lightTheme,
        home: home ?? const LobbyScreen(),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleSpaces = [
    const SpaceModel(
      slug: 'english_b2',
      displayName: 'B2 – Conversational',
      cefrLevel: 'b2',
      voiceCallEnabled: true,
      ttsEnabled: true,
      starterPrompts: [
        'How was your day?',
        'Can we practice debate?',
        'Tell me an interesting story.',
      ],
    ),
    const SpaceModel(
      slug: 'tech',
      displayName: 'Teknologi',
      cefrLevel: null,
      voiceCallEnabled: false,
      ttsEnabled: false,
      starterPrompts: [
        'Jelaskan arsitektur microservices.',
        'Apa kelebihan Flutter?',
      ],
    ),
  ];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Glitch-Free Session Startup & Navigation Pre-resolve', () {
    testWidgets(
        'ChatScreen with pre-resolved sessionId and spaceSlug avoids session creation cascade',
        (tester) async {
      final chatRepo = FakeFullChatRepo();
      final preExistingSession = SessionModel(
        id: 'pre_resolved_123',
        title: 'B2 – Conversational',
        spaceSlug: 'english_b2',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      chatRepo.sessions = [preExistingSession];

      await tester.pumpWidget(createTestApp(
        chatRepo: chatRepo,
        spaces: sampleSpaces,
        home: const ChatScreen(
          sessionId: 'pre_resolved_123',
          spaceSlug: 'english_b2',
        ),
      ));

      await tester.pumpAndSettle();

      // Verify ChatScreen renders correctly with pre-resolved session title
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(find.text('B2 – Conversational'), findsWidgets);

      // Verify no extra session was created inside ChatScreen initState
      expect(chatRepo.createSessionCallCount, 0);
      expect(chatRepo.connectedSessionId, 'pre_resolved_123');

      // Verify dynamic starter prompts rendered without flashing
      expect(find.text('How was your day?'), findsOneWidget);
      expect(find.text('Can we practice debate?'), findsOneWidget);
    });

    testWidgets(
        'LobbyScreen.preResolveAndNavigateToChat pre-resolves session and pushes ChatScreen',
        (tester) async {
      final chatRepo = FakeFullChatRepo();
      chatRepo.sessions = [];

      await tester.pumpWidget(createTestApp(
        chatRepo: chatRepo,
        spaces: sampleSpaces,
        home: Consumer(
          builder: (context, ref, _) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  LobbyScreen.preResolveAndNavigateToChat(
                    context,
                    ref,
                    sampleSpaces.firstWhere((s) => s.slug == 'tech'),
                  );
                },
                child: const Text('Start Tech Chat'),
              ),
            );
          },
        ),
      ));

      await tester.pumpAndSettle();

      // Tap to trigger pre-resolve navigation
      await tester.tap(find.text('Start Tech Chat'));
      await tester.pumpAndSettle();

      // Should be on ChatScreen with tech space
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(find.text('Teknologi'), findsWidgets);
      expect(chatRepo.createSessionCallCount, 1);
      expect(chatRepo.connectedSessionId, isNotNull);
      expect(find.text('Jelaskan arsitektur microservices.'), findsOneWidget);
    });

    testWidgets(
        'LevelPickerScreen.preResolveAndNavigateToChat pre-resolves session and pushes ChatScreen',
        (tester) async {
      final chatRepo = FakeFullChatRepo();
      final existingB2 = SessionModel(
        id: 'b2_existing_session',
        title: 'B2 – Conversational',
        spaceSlug: 'english_b2',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      chatRepo.sessions = [existingB2];

      await tester.pumpWidget(createTestApp(
        chatRepo: chatRepo,
        spaces: sampleSpaces,
        home: Consumer(
          builder: (context, ref, _) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  LevelPickerScreen.preResolveAndNavigateToChat(
                    context,
                    ref,
                    sampleSpaces.firstWhere((s) => s.slug == 'english_b2'),
                  );
                },
                child: const Text('Start B2 Chat'),
              ),
            );
          },
        ),
      ));

      await tester.pumpAndSettle();

      // Tap to trigger pre-resolve navigation
      await tester.tap(find.text('Start B2 Chat'));
      await tester.pumpAndSettle();

      // Should be on ChatScreen using the existing session without creating a new one
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(find.text('B2 – Conversational'), findsWidgets);
      expect(chatRepo.createSessionCallCount, 0);
      expect(chatRepo.connectedSessionId, 'b2_existing_session');
    });

    testWidgets(
        'SessionListScreen pushes ChatScreen with immutable sessionId and spaceSlug',
        (tester) async {
      final chatRepo = FakeFullChatRepo();
      final session = SessionModel(
        id: 'session_list_item_1',
        title: 'B2 – Conversational',
        spaceSlug: 'english_b2',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      chatRepo.sessions = [session];

      await tester.pumpWidget(createTestApp(
        chatRepo: chatRepo,
        spaces: sampleSpaces,
        home: SessionListScreen(space: sampleSpaces.first),
      ));

      await tester.pumpAndSettle();

      // Tap on the session item
      await tester.tap(find.byType(SessionListItem));
      await tester.pumpAndSettle();

      // ChatScreen should be displayed with this session
      expect(find.byType(ChatScreen), findsOneWidget);
      final chatScreenWidget =
          tester.widget<ChatScreen>(find.byType(ChatScreen));
      expect(chatScreenWidget.sessionId, 'session_list_item_1');
      expect(chatScreenWidget.spaceSlug, 'english_b2');
    });
  });
}
