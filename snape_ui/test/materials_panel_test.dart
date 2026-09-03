import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snape_ui/core/services/audio_queue_service.dart';
import 'package:snape_ui/core/theme/app_theme.dart';
import 'package:snape_ui/data/models/websocket_events.dart';
import 'package:snape_ui/domain/models/chat_message.dart';
import 'package:snape_ui/domain/models/session.dart';
import 'package:snape_ui/domain/repositories/chat_repository.dart';
import 'package:snape_ui/domain/repositories/material_repository.dart';
import 'package:snape_ui/presentation/state/providers.dart';
import 'package:snape_ui/presentation/widgets/material_vocab_card.dart';
import 'package:snape_ui/presentation/widgets/materials_panel.dart';

class MockAudioPlayerAdapter implements AudioPlayerAdapter {
  final StreamController<void> _completeController =
      StreamController<void>.broadcast();

  @override
  Stream<void> get onPlayerComplete => _completeController.stream;

  @override
  Future<void> playBytes(Uint8List bytes, {String? mimeType}) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    await _completeController.close();
  }
}

class MockMaterialRepository implements MaterialRepository {
  final Map<String, String?> materials = {};
  bool shouldThrow = false;
  Duration delay = Duration.zero;

  @override
  Future<String?> getMaterial(String spaceSlug, String category) async {
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }
    if (shouldThrow) {
      throw Exception('Connection failed');
    }
    return materials['$spaceSlug/$category'];
  }
}

class MockChatRepository implements ChatRepository {
  final List<String> synthesizedTexts = [];
  bool shouldThrowTts = false;

  @override
  Future<Uint8List> synthesizeAudio(String text) async {
    if (shouldThrowTts) throw Exception('TTS error');
    synthesizedTexts.add(text);
    return Uint8List.fromList([82, 73, 70, 70, 0, 0, 0, 0]); // RIFF dummy header
  }

  @override
  Stream<WSOutputEvent> get chatEvents => const Stream.empty();

  @override
  Stream<bool> get connectionStatus => const Stream.empty();

  @override
  Future<void> connectToChatStream(String sessionId) async {}

  @override
  Future<SessionModel> createSession({
    String title = 'Casual English Chat',
    String spaceSlug = 'english_b2',
  }) async =>
      SessionModel(
        id: 's1',
        title: title,
        spaceSlug: spaceSlug,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  @override
  Future<void> deleteSession(String sessionId) async {}

  @override
  Future<void> disconnectStream() async {}

  @override
  void dispose() {}

  @override
  Future<List<ChatMessage>> getSessionHistory(String sessionId) async => [];

  @override
  Future<List<SessionModel>> getSessions({String? spaceSlug}) async => [];

  @override
  bool get isConnected => false;

  @override
  Future<SessionModel> updateSessionTitle(String sessionId, String title) async =>
      SessionModel(
        id: sessionId,
        title: title,
        spaceSlug: 'space',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  @override
  void sendChatMessage(String content) {}
}

Widget createMaterialsTestApp({
  required MockMaterialRepository repository,
  MockChatRepository? chatRepository,
  AudioQueueService? audioQueueService,
  String spaceSlug = 'english_b2',
  String? cefrLevel = 'B2',
  String? displayName = 'English Chat (B2)',
}) {
  return ProviderScope(
    overrides: [
      materialRepositoryProvider.overrideWithValue(repository),
      audioQueueServiceProvider.overrideWithValue(
        audioQueueService ??
            AudioQueueService(playerAdapter: MockAudioPlayerAdapter()),
      ),
      if (chatRepository != null)
        chatRepositoryProvider.overrideWithValue(chatRepository),
    ],
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, child) => MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: MaterialsPanel(
            spaceSlug: spaceSlug,
            cefrLevel: cefrLevel,
            displayName: displayName,
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MaterialsPanel Widget Tests', () {
    late MockMaterialRepository repository;
    late MockChatRepository chatRepository;

    setUp(() {
      repository = MockMaterialRepository();
      chatRepository = MockChatRepository();
      repository.materials['english_b2/cheatsheet'] = '# B2 Grammar Cheatsheet\n- Present Perfect Continuous';
      repository.materials['english_b2/vocab-formal'] =
          '---\nTitle: "vocab"\n---\n# B2 Formal Vocab\n- **Furthermore** /fɜː.ðəˈmɔː/ (adverb) — In addition to.\n  - *Furthermore, we need more tests.*';
    });

    testWidgets('renders category tabs Cheatsheet, Vocab Formal, Slang', (tester) async {
      await tester.pumpWidget(createMaterialsTestApp(
        repository: repository,
        chatRepository: chatRepository,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Cheatsheet'), findsOneWidget);
      expect(find.text('Vocab Formal'), findsOneWidget);
      expect(find.text('Slang'), findsOneWidget);
    });

    testWidgets('shows loading state while fetching material', (tester) async {
      repository.delay = const Duration(milliseconds: 300);
      await tester.pumpWidget(createMaterialsTestApp(
        repository: repository,
        chatRepository: chatRepository,
      ));
      await tester.pump();

      expect(find.byType(AnimatedBuilder), findsWidgets);

      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.textContaining('Present Perfect Continuous'), findsOneWidget);
    });

    testWidgets('displays content when material is loaded successfully', (tester) async {
      await tester.pumpWidget(createMaterialsTestApp(
        repository: repository,
        chatRepository: chatRepository,
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Present Perfect Continuous'), findsOneWidget);
    });

    testWidgets('switches tab and loads category content lazily as rich cards', (tester) async {
      await tester.pumpWidget(createMaterialsTestApp(
        repository: repository,
        chatRepository: chatRepository,
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Present Perfect Continuous'), findsOneWidget);

      await tester.tap(find.text('Vocab Formal'));
      await tester.pumpAndSettle();

      expect(find.byType(MaterialVocabCard), findsOneWidget);
      expect(find.text('Furthermore'), findsOneWidget);
      expect(find.text('/fɜː.ðəˈmɔː/'), findsOneWidget);
      expect(find.text('adverb'), findsOneWidget);
      expect(find.text('In addition to.'), findsOneWidget);
      expect(find.textContaining('Furthermore, we need more tests.'), findsOneWidget);
    });

    testWidgets('tapping speaker button on vocab card synthesizes audio', (tester) async {
      await tester.pumpWidget(createMaterialsTestApp(
        repository: repository,
        chatRepository: chatRepository,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Vocab Formal'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.volume_up_rounded));
      await tester.pumpAndSettle();

      expect(chatRepository.synthesizedTexts.length, 1);
      expect(chatRepository.synthesizedTexts.first, contains('Furthermore. In addition to.'));
    });

    testWidgets('displays empty state message on 404 null content', (tester) async {
      await tester.pumpWidget(createMaterialsTestApp(
        repository: repository,
        chatRepository: chatRepository,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Slang'));
      await tester.pumpAndSettle();

      expect(find.text('Materi untuk level ini belum tersedia'), findsOneWidget);
    });

    testWidgets('displays error state and retries on failure', (tester) async {
      repository.shouldThrow = true;

      await tester.pumpWidget(createMaterialsTestApp(
        repository: repository,
        chatRepository: chatRepository,
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Connection failed'), findsOneWidget);
      expect(find.text('Coba Lagi'), findsOneWidget);

      repository.shouldThrow = false;
      await tester.tap(find.text('Coba Lagi'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Present Perfect Continuous'), findsOneWidget);
    });
  });
}
