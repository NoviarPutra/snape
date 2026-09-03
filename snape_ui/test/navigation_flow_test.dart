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
import 'package:snape_ui/presentation/state/providers.dart';

class FakeFullChatRepository implements ChatRepository {
  List<SessionModel> sessions = [];

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
    final session = SessionModel(
      id: 'session_${DateTime.now().millisecondsSinceEpoch}',
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

class FakeFullSpaceRepository implements SpaceRepository {
  final List<SpaceModel> spaces;
  FakeFullSpaceRepository(this.spaces);

  @override
  Future<List<SpaceModel>> getSpaces() async => spaces;
}

class FakeFullUserRepository implements UserRepository {
  @override
  Future<UserModel> getUserProfile() async => const UserModel(
        id: 'u1',
        username: 'learner',
        englishLevel: 'Intermediate',
      );
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

Widget createFullApp({
  required FakeFullChatRepository chatRepo,
  required List<SpaceModel> spaces,
}) {
  return ProviderScope(
    overrides: [
      chatRepositoryProvider.overrideWithValue(chatRepo),
      spaceRepositoryProvider.overrideWithValue(FakeFullSpaceRepository(spaces)),
      userRepositoryProvider.overrideWithValue(FakeFullUserRepository()),
      speechServiceProvider.overrideWithValue(FakeSpeechService()),
      memoryRepositoryProvider.overrideWithValue(FakeMemoryRepository()),
    ],
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, child) => MaterialApp(
        theme: AppTheme.lightTheme,
        home: const LobbyScreen(),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testSpaces = [
    const SpaceModel(
      slug: 'english_b2',
      displayName: 'B2 – Conversational',
      cefrLevel: 'b2',
      voiceCallEnabled: true,
      ttsEnabled: true,
    ),
    const SpaceModel(
      slug: 'tech',
      displayName: 'Teknologi',
      cefrLevel: null,
      voiceCallEnabled: false,
      ttsEnabled: false,
    ),
    const SpaceModel(
      slug: 'psychology',
      displayName: 'Psikologi',
      cefrLevel: null,
      voiceCallEnabled: false,
      ttsEnabled: false,
    ),
    const SpaceModel(
      slug: 'productivity',
      displayName: 'Produktivitas',
      cefrLevel: null,
      voiceCallEnabled: false,
      ttsEnabled: false,
    ),
  ];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'Full flow: Lobby -> LevelPicker -> SessionList -> Chat (English space has Voice Call)',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final chatRepo = FakeFullChatRepository();
    await tester.pumpWidget(createFullApp(chatRepo: chatRepo, spaces: testSpaces));
    await tester.pumpAndSettle();

    expect(find.byType(LobbyScreen), findsOneWidget);

    // Tap English Learning
    await tester.tap(find.text('English Learning Companion'));
    await tester.pumpAndSettle();

    expect(find.byType(LevelPickerScreen), findsOneWidget);

    // Tap B2
    await tester.tap(find.text('B2 – Conversational'));
    await tester.pumpAndSettle();

    expect(find.byType(SessionListScreen), findsOneWidget);

    // Tap Start Conversation
    await tester.tap(find.text('Start Conversation'));
    await tester.pumpAndSettle();

    expect(find.byType(ChatScreen), findsOneWidget);

    // Verify Voice Call button is visible for English space
    expect(find.byTooltip('Start Voice Call'), findsWidgets);

    // Tap back button
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.byType(SessionListScreen), findsOneWidget);

    // Tap back to LevelPicker
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(LevelPickerScreen), findsOneWidget);

    // Tap back to Lobby
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(LobbyScreen), findsOneWidget);
  });

  testWidgets(
      'Full flow: Lobby -> SessionList -> Chat (Non-English space hides Voice Call)',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final chatRepo = FakeFullChatRepository();
    await tester.pumpWidget(createFullApp(chatRepo: chatRepo, spaces: testSpaces));
    await tester.pumpAndSettle();

    // Tap Teknologi space
    await tester.tap(find.text('Teknologi'));
    await tester.pumpAndSettle();

    expect(find.byType(SessionListScreen), findsOneWidget);
    expect(find.text('Teknologi'), findsWidgets);

    // Tap Start Conversation
    await tester.tap(find.text('Start Conversation'));
    await tester.pumpAndSettle();

    expect(find.byType(ChatScreen), findsOneWidget);

    // Verify Voice Call button is NOT present for Tech space
    expect(find.byTooltip('Start Voice Call'), findsNothing);
    expect(find.byIcon(Icons.phone_in_talk_rounded), findsNothing);

    // Tap back to SessionList
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.byType(SessionListScreen), findsOneWidget);
  });
}
