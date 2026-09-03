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
import 'package:snape_ui/domain/repositories/chat_repository.dart';
import 'package:snape_ui/domain/repositories/material_repository.dart';
import 'package:snape_ui/domain/repositories/memory_repository.dart';
import 'package:snape_ui/domain/repositories/space_repository.dart';
import 'package:snape_ui/presentation/screens/chat_screen.dart';
import 'package:snape_ui/presentation/state/providers.dart';
import 'package:snape_ui/presentation/widgets/materials_panel.dart';

class FakeChatRepository implements ChatRepository {
  final _eventController = StreamController<WSOutputEvent>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final List<String> sentMessages = [];
  bool connected = false;
  List<ChatMessage> mockHistory = [];
  final List<SessionModel> sessions = [];

  @override
  Future<List<SessionModel>> getSessions({String? spaceSlug}) async {
    if (spaceSlug != null) {
      return sessions.where((s) => s.spaceSlug == spaceSlug).toList();
    }
    return sessions;
  }

  @override
  Future<SessionModel> createSession({
    String title = 'Casual English Practice',
    String spaceSlug = 'english_b2',
  }) async {
    final session = SessionModel(
      id: 'sess-test-${sessions.length + 1}',
      title: title,
      spaceSlug: spaceSlug,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    sessions.add(session);
    return session;
  }

  @override
  Future<List<ChatMessage>> getSessionHistory(String sessionId) async {
    return mockHistory;
  }

  @override
  Future<void> deleteSession(String sessionId) async {
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
  Future<Uint8List> synthesizeAudio(String text) async =>
      Uint8List.fromList([1, 2, 3]);

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

  @override
  Future<void> dispose() async {
    await _eventController.close();
    await _connectionController.close();
  }
}

class MockMemoryRepository implements MemoryRepository {
  @override
  Future<List<MemoryItem>> getMemories({
    int limit = 50,
    int offset = 0,
    String? category,
  }) async =>
      [];

  @override
  Future<void> deleteMemory(String memoryId) async {}
}

class MockSpeechService implements BaseSpeechService {
  @override
  bool get isAvailable => true;

  @override
  bool get isListening => false;

  @override
  Future<bool> initialize() async => true;

  @override
  Future<void> startListening({
    required Function(String text, bool isFinal) onResult,
    Function(bool isListening)? onListeningStateChanged,
    String localeId = 'id_ID',
  }) async {}

  @override
  Future<void> stopListening() async {}
}

class MockMaterialRepository implements MaterialRepository {
  final Map<String, String?> materials = {};

  @override
  Future<String?> getMaterial(String spaceSlug, String category) async {
    return materials['$spaceSlug/$category'];
  }
}

class MockSpaceRepository implements SpaceRepository {
  List<SpaceModel> spaces = [];

  @override
  Future<List<SpaceModel>> getSpaces() async => spaces;
}

Widget createChatScreenTestApp({
  required FakeChatRepository chatRepository,
  required MockMaterialRepository materialRepository,
  required MockSpaceRepository spaceRepository,
  SpaceModel? initialActiveSpace,
}) {
  return ProviderScope(
    overrides: [
      chatRepositoryProvider.overrideWithValue(chatRepository),
      memoryRepositoryProvider.overrideWithValue(MockMemoryRepository()),
      speechServiceProvider.overrideWithValue(MockSpeechService()),
      materialRepositoryProvider.overrideWithValue(materialRepository),
      spaceRepositoryProvider.overrideWithValue(spaceRepository),
    ],
    child: Consumer(
      builder: (context, ref, child) {
        if (initialActiveSpace != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(spaceProvider.notifier).selectSpace(initialActiveSpace);
          });
        }
        return ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (context, child) => MaterialApp(
            theme: AppTheme.lightTheme,
            home: const ChatScreen(),
          ),
        );
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatScreen Materials Integration', () {
    late FakeChatRepository chatRepository;
    late MockMaterialRepository materialRepository;
    late MockSpaceRepository spaceRepository;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      chatRepository = FakeChatRepository();
      materialRepository = MockMaterialRepository();
      spaceRepository = MockSpaceRepository();

      materialRepository.materials['english_b2/cheatsheet'] =
          '# B2 Cheatsheet Content';
    });

    testWidgets('shows Materials button when activeSpace is English (cefrLevel != null)', (tester) async {
      final englishSpace = const SpaceModel(
        slug: 'english_b2',
        displayName: 'English Chat (B2)',
        cefrLevel: 'B2',
        voiceCallEnabled: true,
        ttsEnabled: true,
      );

      await tester.pumpWidget(createChatScreenTestApp(
        chatRepository: chatRepository,
        materialRepository: materialRepository,
        spaceRepository: spaceRepository,
        initialActiveSpace: englishSpace,
      ));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Materi'), findsOneWidget);
    });

    testWidgets('hides Materials button when activeSpace is non-English (cefrLevel == null)', (tester) async {
      final nonEnglishSpace = const SpaceModel(
        slug: 'tech',
        displayName: 'Technology & Architecture',
        cefrLevel: null,
        voiceCallEnabled: false,
        ttsEnabled: false,
      );

      await tester.pumpWidget(createChatScreenTestApp(
        chatRepository: chatRepository,
        materialRepository: materialRepository,
        spaceRepository: spaceRepository,
        initialActiveSpace: nonEnglishSpace,
      ));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Materi'), findsNothing);
    });

    testWidgets('tapping Materials button opens MaterialsPanel bottom sheet', (tester) async {
      final englishSpace = const SpaceModel(
        slug: 'english_b2',
        displayName: 'English Chat (B2)',
        cefrLevel: 'B2',
        voiceCallEnabled: true,
        ttsEnabled: true,
      );

      await tester.pumpWidget(createChatScreenTestApp(
        chatRepository: chatRepository,
        materialRepository: materialRepository,
        spaceRepository: spaceRepository,
        initialActiveSpace: englishSpace,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Materi'));
      await tester.pumpAndSettle();

      expect(find.byType(MaterialsPanel), findsOneWidget);
      expect(find.text('Materi Referensi'), findsOneWidget);
      expect(find.textContaining('B2 Cheatsheet Content'), findsOneWidget);
    });
  });
}
