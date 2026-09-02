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
import 'package:snape_ui/domain/models/session.dart';
import 'package:snape_ui/domain/repositories/chat_repository.dart';
import 'package:snape_ui/presentation/screens/voice_call_screen.dart';
import 'package:snape_ui/presentation/state/providers.dart';
import 'package:snape_ui/presentation/state/voice_call_notifier.dart';
import 'package:snape_ui/presentation/widgets/voice_control_bar.dart';
import 'package:snape_ui/presentation/widgets/voice_orb_visualizer.dart';
import 'package:snape_ui/presentation/widgets/voice_subtitle_card.dart';

class MockSpeechService implements BaseSpeechService {
  bool _isAvailable = true;
  bool _isListening = false;
  String currentLocale = 'en_US';
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
    String localeId = 'en_US',
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

  void emitSpeech(String text, {bool isFinal = false}) {
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

  @override
  Future<List<SessionModel>> getSessions() async => [];

  @override
  Future<SessionModel> createSession({String title = 'Casual English Chat'}) async {
    return SessionModel(
      id: 'sess-1',
      title: title,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<List<ChatMessage>> getSessionHistory(String sessionId) async => [];

  @override
  Future<void> deleteSession(String sessionId) async {}

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

Widget createVoiceCallScreenTestWrapper({
  required BaseSpeechService speechService,
  required ChatRepository chatRepository,
  VoiceCallNotifier? customVoiceNotifier,
  NavigatorObserver? navigatorObserver,
}) {
  return ProviderScope(
    overrides: [
      speechServiceProvider.overrideWithValue(speechService),
      chatRepositoryProvider.overrideWithValue(chatRepository),
      if (customVoiceNotifier != null)
        voiceCallProvider.overrideWith((ref) => customVoiceNotifier),
    ],
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) => MaterialApp(
        theme: AppTheme.lightTheme,
        navigatorObservers: navigatorObserver != null ? [navigatorObserver] : [],
        home: const VoiceCallScreen(),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VoiceCallScreen', () {
    late MockSpeechService mockSpeechService;
    late FakeChatRepository mockChatRepo;

    setUp(() {
      mockSpeechService = MockSpeechService();
      mockChatRepo = FakeChatRepository();
    });

    testWidgets('renders all core components and dark theme layout', (WidgetTester tester) async {
      await tester.pumpWidget(
        createVoiceCallScreenTestWrapper(
          speechService: mockSpeechService,
          chatRepository: mockChatRepo,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(VoiceCallScreen), findsOneWidget);
      expect(find.byType(VoiceOrbVisualizer), findsOneWidget);
      expect(find.byType(VoiceSubtitleCard), findsOneWidget);
      expect(find.byType(VoiceControlBar), findsOneWidget);
      expect(find.byKey(const Key('voice_call_close_button')), findsOneWidget);
    });

    testWidgets('triggers proactive greeting upon entering screen', (WidgetTester tester) async {
      await tester.pumpWidget(
        createVoiceCallScreenTestWrapper(
          speechService: mockSpeechService,
          chatRepository: mockChatRepo,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text("Hey there! It's great to hear from you. What's on your mind today?"), findsOneWidget);
    });

    testWidgets('controls toggle mute, language, subtitles, and end call', (WidgetTester tester) async {
      await tester.pumpWidget(
        createVoiceCallScreenTestWrapper(
          speechService: mockSpeechService,
          chatRepository: mockChatRepo,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Toggle Mute
      await tester.tap(find.byKey(const Key('voice_control_mute_button')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byIcon(Icons.mic_off_rounded), findsOneWidget);

      // Toggle Language
      await tester.tap(find.byKey(const Key('voice_control_language_button')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('ID'), findsOneWidget);

      // Toggle Subtitles
      await tester.tap(find.byKey(const Key('voice_control_subtitles_button')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byIcon(Icons.subtitles_off_rounded), findsOneWidget);

      // End Call button
      await tester.tap(find.byKey(const Key('voice_control_end_call_button')));
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('displays error feedback when mic permission / speech is denied', (WidgetTester tester) async {
      mockSpeechService.isAvailable = false;

      await tester.pumpWidget(
        createVoiceCallScreenTestWrapper(
          speechService: mockSpeechService,
          chatRepository: mockChatRepo,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('voice_call_error_banner')), findsOneWidget);
      expect(find.textContaining('Microphone'), findsOneWidget);
    });

    testWidgets('close button calls Navigator.maybePop', (WidgetTester tester) async {
      await tester.pumpWidget(
        createVoiceCallScreenTestWrapper(
          speechService: mockSpeechService,
          chatRepository: mockChatRepo,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('voice_call_close_button')));
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
