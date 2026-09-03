import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snape_ui/core/services/audio_queue_service.dart';
import 'package:snape_ui/core/services/speech_service.dart';
import 'package:snape_ui/core/theme/app_theme.dart';
import 'package:snape_ui/data/models/websocket_events.dart';
import 'package:snape_ui/domain/models/chat_message.dart';
import 'package:snape_ui/domain/models/session.dart';
import 'package:snape_ui/domain/repositories/chat_repository.dart';
import 'package:snape_ui/domain/repositories/memory_repository.dart';
import 'package:snape_ui/domain/models/memory_item.dart';
import 'package:snape_ui/presentation/screens/chat_screen.dart';
import 'package:snape_ui/presentation/screens/voice_call_screen.dart';
import 'package:snape_ui/presentation/state/providers.dart';
import 'package:snape_ui/presentation/widgets/chat_input_bar.dart';
import 'package:snape_ui/presentation/widgets/message_bubble.dart';

class MockSpeechService implements BaseSpeechService {
  bool _isAvailable = true;
  bool _isListening = false;
  String currentLocale = 'id_ID';
  Function(String text, bool isFinal)? onResultCallback;
  Function(bool isListening)? onListeningStateChanged;

  @override
  bool get isAvailable => _isAvailable;

  @override
  bool get isListening => _isListening;

  set isAvailable(bool val) => _isAvailable = val;

  @override
  Future<bool> initialize() async => _isAvailable;

  @override
  Future<void> startListening({
    required Function(String text, bool isFinal) onResult,
    Function(bool isListening)? onListeningStateChanged,
    String localeId = 'id_ID',
  }) async {
    _isListening = true;
    currentLocale = localeId;
    onResultCallback = onResult;
    this.onListeningStateChanged = onListeningStateChanged;
    onListeningStateChanged?.call(true);
  }

  @override
  Future<void> stopListening() async {
    _isListening = false;
    onListeningStateChanged?.call(false);
  }

  void emitSpeech(String text, {bool isFinal = true}) {
    onResultCallback?.call(text, isFinal);
    if (isFinal) {
      _isListening = false;
      onListeningStateChanged?.call(false);
    }
  }
}

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
        id: 'sess-test-1',
        title: 'Voice Practice Session',
        spaceSlug: spaceSlug ?? 'english_b2',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      )
    ];
  }

  @override
  Future<SessionModel> createSession({
    String title = 'Casual English Practice',
    String spaceSlug = 'english_b2',
  }) async {
    return SessionModel(
      id: 'sess-test-1',
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
  Future<SessionModel> updateSessionTitle(String sessionId, String title) async {
    return SessionModel(
      id: sessionId,
      title: title,
      spaceSlug: 'english_b2',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<Uint8List> synthesizeAudio(String text) async => Uint8List.fromList([1, 2, 3]);

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

  void emitEvent(WSOutputEvent event) {
    _eventController.add(event);
  }
}

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

class FakeMemoryRepository implements MemoryRepository {
  @override
  Future<List<MemoryItem>> getMemories({int limit = 50, int offset = 0, String? category}) async {
    return [];
  }

  @override
  Future<void> deleteMemory(String memoryId) async {}
}

Widget createTestApp({
  required FakeChatRepository chatRepo,
  required MockSpeechService speechService,
}) {
  return ProviderScope(
    overrides: [
      chatRepositoryProvider.overrideWithValue(chatRepo),
      speechServiceProvider.overrideWithValue(speechService),
      audioQueueServiceProvider.overrideWithValue(
        AudioQueueService(playerAdapter: MockAudioPlayerAdapter()),
      ),
      memoryRepositoryProvider.overrideWithValue(FakeMemoryRepository()),
    ],
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, child) => MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ChatScreen(),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeChatRepository fakeChatRepo;
  late MockSpeechService mockSpeechService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeChatRepo = FakeChatRepository();
    mockSpeechService = MockSpeechService();
  });

  tearDown(() async {
    await fakeChatRepo.dispose();
  });

  group('ChatScreen Voice Call Entry Point and Navigation Integration', () {
    testWidgets('AppBar contains voice call button and tapping it opens VoiceCallScreen', (tester) async {
      await tester.pumpWidget(createTestApp(
        chatRepo: fakeChatRepo,
        speechService: mockSpeechService,
      ));
      await tester.pumpAndSettle();

      final callButtonFinder = find.byTooltip('Start Voice Call');
      expect(callButtonFinder, findsWidgets);

      // Tap the AppBar voice call icon
      await tester.tap(callButtonFinder.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // VoiceCallScreen should now be in the widget tree
      expect(find.byType(VoiceCallScreen), findsOneWidget);
    });

    testWidgets('Quick input area has voice call button when input is empty and opens VoiceCallScreen', (tester) async {
      await tester.pumpWidget(createTestApp(
        chatRepo: fakeChatRepo,
        speechService: mockSpeechService,
      ));
      await tester.pumpAndSettle();

      // Quick action button in input bar should also have Start Voice Call tooltip
      final quickVoiceButton = find.descendant(
        of: find.byType(ChatScreen),
        matching: find.byTooltip('Start Voice Call'),
      );
      expect(quickVoiceButton, findsWidgets);

      // Tap the quick voice action button in the input bar
      await tester.tap(quickVoiceButton.last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(VoiceCallScreen), findsOneWidget);
    });

    testWidgets('End-to-end voice conversation turns appear in ChatScreen upon ending call', (tester) async {
      await tester.pumpWidget(createTestApp(
        chatRepo: fakeChatRepo,
        speechService: mockSpeechService,
      ));
      await tester.pumpAndSettle();

      // Tap AppBar voice call button to start voice call
      await tester.tap(find.byTooltip('Start Voice Call').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(VoiceCallScreen), findsOneWidget);

      // Simulate user speech in voice call
      mockSpeechService.emitSpeech('I went to market yesterday and buyed apples', isFinal: true);
      await tester.pump();

      // Verify message was sent to chat repository
      expect(fakeChatRepo.sentMessages, contains('I went to market yesterday and buyed apples'));

      // Simulate backend streaming response and turn completed
      fakeChatRepo.emitEvent(const WSTokenEvent(content: 'That sounds nice!'));
      fakeChatRepo.emitEvent(const WSTokenEvent(content: ' By the way, we usually say bought apples.'));
      fakeChatRepo.emitEvent(const WSDoneEvent(
        sessionId: 'sess-test-1',
        fullText: 'That sounds nice! By the way, we usually say bought apples.',
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // End call using End Call button
      final endCallButton = find.byKey(const Key('voice_control_end_call_button'));
      expect(endCallButton, findsOneWidget);
      await tester.tap(endCallButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Should be back to ChatScreen
      expect(find.byType(VoiceCallScreen), findsNothing);
      expect(find.byType(ChatScreen), findsOneWidget);

      // Verify that conversation turns are reflected in MessageBubble widgets
      expect(find.byType(MessageBubble), findsNWidgets(2));
      expect(find.text('I went to market yesterday and buyed apples'), findsOneWidget);
      expect(find.text('That sounds nice! By the way, we usually say bought apples.'), findsOneWidget);
    });

    testWidgets('Header close button in VoiceCallScreen ends call and navigates back to ChatScreen', (tester) async {
      await tester.pumpWidget(createTestApp(
        chatRepo: fakeChatRepo,
        speechService: mockSpeechService,
      ));
      await tester.pumpAndSettle();

      // Open VoiceCallScreen
      await tester.tap(find.byTooltip('Start Voice Call').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(VoiceCallScreen), findsOneWidget);

      // Tap Header close button
      final closeButtonFinder = find.byKey(const Key('voice_call_close_button'));
      expect(closeButtonFinder, findsOneWidget);
      await tester.tap(closeButtonFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.byType(VoiceCallScreen), findsNothing);
      expect(find.byType(ChatScreen), findsOneWidget);
    });

    testWidgets('Typing in ChatInputBar dynamically transforms quick voice call button into send button and back', (tester) async {
      await tester.pumpWidget(createTestApp(
        chatRepo: fakeChatRepo,
        speechService: mockSpeechService,
      ));
      await tester.pumpAndSettle();

      // Initially empty -> input bar button is Start Voice Call
      final inputBarVoiceButton = find.descendant(
        of: find.byType(ChatInputBar),
        matching: find.byTooltip('Start Voice Call'),
      );
      expect(inputBarVoiceButton, findsOneWidget);

      // Type some text
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'Hello from keyboard');
      await tester.pumpAndSettle();

      // Now input bar button becomes Send Message
      final inputBarSendButton = find.descendant(
        of: find.byType(ChatInputBar),
        matching: find.byTooltip('Send Message'),
      );
      expect(inputBarSendButton, findsOneWidget);
      expect(find.descendant(of: find.byType(ChatInputBar), matching: find.byTooltip('Start Voice Call')), findsNothing);

      // Send the message
      await tester.tap(inputBarSendButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Message should be sent and input cleared -> switches back to Start Voice Call
      expect(fakeChatRepo.sentMessages, contains('Hello from keyboard'));
      expect(find.descendant(of: find.byType(ChatInputBar), matching: find.byTooltip('Start Voice Call')), findsOneWidget);
    });
  });
}
