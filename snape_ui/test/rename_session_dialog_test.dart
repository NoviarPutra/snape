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
import 'package:snape_ui/domain/repositories/chat_repository.dart';
import 'package:snape_ui/domain/repositories/memory_repository.dart';
import 'package:snape_ui/presentation/screens/chat_screen.dart';
import 'package:snape_ui/presentation/state/providers.dart';
import 'package:snape_ui/presentation/state/session_notifier.dart';
import 'package:snape_ui/presentation/widgets/rename_session_dialog.dart';
import 'package:snape_ui/presentation/widgets/session_drawer.dart';

class FakeChatRepoForRename implements ChatRepository {
  List<SessionModel> sessions = [];
  String? updatedSessionId;
  String? updatedSessionTitle;

  final _eventController = StreamController<WSOutputEvent>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

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
      id: 'sess-${sessions.length + 1}',
      title: title,
      spaceSlug: spaceSlug,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    sessions.insert(0, session);
    return session;
  }

  @override
  Future<SessionModel> updateSessionTitle(String sessionId, String title) async {
    updatedSessionId = sessionId;
    updatedSessionTitle = title;
    final index = sessions.indexWhere((s) => s.id == sessionId);
    if (index == -1) {
      final created = SessionModel(
        id: sessionId,
        title: title,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      sessions.add(created);
      return created;
    }
    final updated = sessions[index].copyWith(title: title, updatedAt: DateTime.now());
    sessions[index] = updated;
    return updated;
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
  Future<void> disconnectStream() async {}

  @override
  void dispose() {
    _eventController.close();
    _connectionController.close();
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
}

class FakeMemoryRepo implements MemoryRepository {
  @override
  Future<List<MemoryItem>> getMemories(
          {int limit = 50, int offset = 0, String? category}) async =>
      [];
  @override
  Future<void> deleteMemory(String memoryId) async {}
}

Widget createDialogTestWrapper({required Widget child}) {
  return MaterialApp(
    home: ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) => Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RenameSessionDialog', () {
    testWidgets('renders initial title in TextField and cancels when Cancel is pressed',
        (tester) async {
      String? result;

      await tester.pumpWidget(
        createDialogTestWrapper(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await RenameSessionDialog.show(
                  context,
                  currentTitle: 'My Practice Topic',
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Rename Session'), findsOneWidget);
      expect(find.text('My Practice Topic'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Rename Session'), findsNothing);
      expect(result, isNull);
    });

    testWidgets('submits new title when Save is pressed', (tester) async {
      String? result;

      await tester.pumpWidget(
        createDialogTestWrapper(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await RenameSessionDialog.show(
                  context,
                  currentTitle: 'Old Title',
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'New Cool Title');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Rename Session'), findsNothing);
      expect(result, 'New Cool Title');
    });

    testWidgets('disables Save button when text is cleared', (tester) async {
      await tester.pumpWidget(
        createDialogTestWrapper(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                await RenameSessionDialog.show(
                  context,
                  currentTitle: 'Initial Title',
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pumpAndSettle();

      final saveButton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Save'));
      expect(saveButton.onPressed, isNull);
    });
  });

  group('SessionDrawer & ChatScreen rename interactions', () {
    testWidgets('SessionDrawer rename action triggers rename callback', (tester) async {
      SessionModel? renamedSession;

      final session1 = SessionModel(
        id: 'sess-1',
        title: 'Drawer Session 1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (context, _) => Scaffold(
              body: SessionDrawer(
                sessions: [session1],
                currentSession: session1,
                onSelectSession: (_) {},
                onCreateSession: () {},
                onRenameSession: (session) {
                  renamedSession = session;
                },
                onDeleteSession: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Drawer Session 1'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      expect(renamedSession?.id, 'sess-1');
    });

    testWidgets('Tapping ChatScreen AppBar title opens RenameSessionDialog and renames session',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final chatRepo = FakeChatRepoForRename()
        ..sessions = [
          SessionModel(
            id: 'sess-chat-1',
            title: 'Chat Header Initial',
            spaceSlug: 'english_b2',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

      final container = ProviderContainer(
        overrides: [
          chatRepositoryProvider.overrideWithValue(chatRepo),
          speechServiceProvider.overrideWithValue(FakeSpeechService()),
          memoryRepositoryProvider.overrideWithValue(FakeMemoryRepo()),
        ],
      );

      // Preload session into sessionNotifier
      await container.read(sessionProvider.notifier).loadSessions();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (context, _) => MaterialApp(
              theme: AppTheme.lightTheme,
              home: const ChatScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chat Header Initial'), findsOneWidget);

      // Tap on the AppBar title
      await tester.tap(find.text('Chat Header Initial'));
      await tester.pumpAndSettle();

      expect(find.text('Rename Session'), findsOneWidget);

      // Enter new title
      await tester.enterText(
        find.descendant(
          of: find.byType(RenameSessionDialog),
          matching: find.byType(TextField),
        ),
        'Chat Header Renamed',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Rename Session'), findsNothing);
      expect(find.text('Chat Header Renamed'), findsOneWidget);
      expect(chatRepo.updatedSessionTitle, 'Chat Header Renamed');
    });
  });
}
