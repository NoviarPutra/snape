import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:snape_ui/core/services/audio_queue_service.dart';
import 'package:snape_ui/core/services/speech_service.dart';
import 'package:snape_ui/data/models/websocket_events.dart';
import 'package:snape_ui/domain/models/chat_message.dart';
import 'package:snape_ui/domain/models/session.dart';
import 'package:snape_ui/domain/repositories/chat_repository.dart';
import 'package:snape_ui/presentation/state/chat_notifier.dart';
import 'package:snape_ui/presentation/state/voice_call_notifier.dart';
import 'package:snape_ui/presentation/state/voice_call_state.dart';

class MockAudioPlayerAdapter implements AudioPlayerAdapter {
  final StreamController<void> _completeController =
      StreamController<void>.broadcast();
  final List<Uint8List> playedChunks = [];
  bool isStopped = false;
  bool isDisposed = false;

  @override
  Stream<void> get onPlayerComplete => _completeController.stream;

  @override
  Future<void> playBytes(Uint8List bytes, {String? mimeType}) async {
    isStopped = false;
    playedChunks.add(bytes);
  }

  @override
  Future<void> stop() async {
    isStopped = true;
  }

  @override
  Future<void> dispose() async {
    isDisposed = true;
    await _completeController.close();
  }

  void completeCurrentPlayback() {
    _completeController.add(null);
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VoiceCallNotifier', () {
    late FakeChatRepository mockChatRepo;
    late MockAudioPlayerAdapter mockPlayerAdapter;
    late AudioQueueService audioQueueService;
    late ChatNotifier chatNotifier;
    late MockSpeechService mockSpeechService;
    late VoiceCallNotifier voiceNotifier;

    setUp(() async {
      mockChatRepo = FakeChatRepository();
      mockPlayerAdapter = MockAudioPlayerAdapter();
      audioQueueService = AudioQueueService(playerAdapter: mockPlayerAdapter);
      chatNotifier = ChatNotifier(mockChatRepo, audioQueueService);
      await chatNotifier.switchSession('sess-1');

      mockSpeechService = MockSpeechService();
      voiceNotifier = VoiceCallNotifier(
        chatNotifier: chatNotifier,
        speechService: mockSpeechService,
        audioQueueService: audioQueueService,
        silenceDuration: const Duration(milliseconds: 100),
      );
    });

    tearDown(() async {
      voiceNotifier.dispose();
      chatNotifier.dispose();
      await audioQueueService.dispose();
      await mockChatRepo.dispose();
    });

    test('initial state is idle with defaults', () {
      expect(voiceNotifier.state.phase, VoiceCallPhase.idle);
      expect(voiceNotifier.state.localeId, 'en_US');
      expect(voiceNotifier.state.isMuted, isFalse);
      expect(voiceNotifier.state.showSubtitles, isTrue);
      expect(voiceNotifier.state.userSpeech, isEmpty);
      expect(voiceNotifier.state.assistantSpeech, isEmpty);
    });

    test('startCall when speechService is unavailable sets errorMessage', () async {
      mockSpeechService.isAvailable = false;
      await voiceNotifier.startCall(withGreeting: true);

      expect(voiceNotifier.state.errorMessage, isNotNull);
      expect(voiceNotifier.state.errorMessage, contains('Microphone'));
      expect(mockSpeechService.isListening, isFalse);
    });

    test('startCall without greeting directly begins listening', () async {
      await voiceNotifier.startCall(withGreeting: false);

      expect(voiceNotifier.state.phase, VoiceCallPhase.listening);
      expect(mockSpeechService.isListening, isTrue);
    });

    test('startCall with proactive greeting enters greeting phase then speaks greeting', () async {
      await voiceNotifier.startCall(
        withGreeting: true,
        greetingText: 'Hello there! How can I help you practice today?',
      );

      expect(voiceNotifier.state.phase, VoiceCallPhase.greeting);
      expect(voiceNotifier.state.assistantSpeech, 'Hello there! How can I help you practice today?');
    });

    test('auto-sends message on final STT result and switches to thinking', () async {
      await voiceNotifier.startCall(withGreeting: false);

      mockSpeechService.emitSpeech('Hello Snape, how are you?', isFinal: true);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(voiceNotifier.state.phase, VoiceCallPhase.thinking);
      expect(mockChatRepo.sentMessages, contains('Hello Snape, how are you?'));
      expect(voiceNotifier.state.userSpeech, 'Hello Snape, how are you?');
    });

    test('auto-sends message on silence timeout for interim speech', () async {
      await voiceNotifier.startCall(withGreeting: false);

      mockSpeechService.emitSpeech('I want to practice English', isFinal: false);
      expect(voiceNotifier.state.userSpeech, 'I want to practice English');
      expect(voiceNotifier.state.phase, VoiceCallPhase.listening);

      // Wait for silence duration (100ms) + buffer
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(voiceNotifier.state.phase, VoiceCallPhase.thinking);
      expect(mockChatRepo.sentMessages, contains('I want to practice English'));
    });

    test('transitions to speaking when companion audio arrives, then returns to listening when playback completes', () async {
      await voiceNotifier.startCall(withGreeting: false);

      mockSpeechService.emitSpeech('Hello', isFinal: true);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(voiceNotifier.state.phase, VoiceCallPhase.thinking);

      // Stream assistant token
      mockChatRepo.emitEvent(const WSTokenEvent(content: 'Great '));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(voiceNotifier.state.assistantSpeech, 'Great ');

      // Stream assistant audio chunk
      mockChatRepo.emitEvent(const WSAudioEvent(sentence: 'Great', audioBase64: 'AQIDBA=='));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(voiceNotifier.state.phase, VoiceCallPhase.speaking);

      // Complete playback
      mockPlayerAdapter.completeCurrentPlayback();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(voiceNotifier.state.phase, VoiceCallPhase.listening);
      expect(mockSpeechService.isListening, isTrue);
    });

    test('instant barge-in cuts off assistant speech when user speaks during speaking phase', () async {
      await voiceNotifier.startCall(withGreeting: false);

      // Transition to speaking
      mockChatRepo.emitEvent(const WSAudioEvent(sentence: 'Hello', audioBase64: 'AQIDBA=='));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(voiceNotifier.state.phase, VoiceCallPhase.speaking);
      expect(audioQueueService.isPlaying, isTrue);

      // User interrupts
      voiceNotifier.bargeIn();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(voiceNotifier.state.phase, VoiceCallPhase.listening);
      expect(audioQueueService.isPlaying, isFalse);
      expect(mockPlayerAdapter.isStopped, isTrue);
    });

    test('toggleLanguage switches between en_US and id_ID and updates STT locale', () async {
      await voiceNotifier.startCall(withGreeting: false);
      expect(voiceNotifier.state.localeId, 'en_US');

      await voiceNotifier.toggleLanguage();
      expect(voiceNotifier.state.localeId, 'id_ID');
      expect(mockSpeechService.currentLocale, 'id_ID');

      await voiceNotifier.toggleLanguage();
      expect(voiceNotifier.state.localeId, 'en_US');
      expect(mockSpeechService.currentLocale, 'en_US');
    });

    test('toggleMute silences and resumes speech listening', () async {
      await voiceNotifier.startCall(withGreeting: false);
      expect(voiceNotifier.state.isMuted, isFalse);
      expect(mockSpeechService.isListening, isTrue);

      await voiceNotifier.toggleMute();
      expect(voiceNotifier.state.isMuted, isTrue);
      expect(mockSpeechService.isListening, isFalse);

      await voiceNotifier.toggleMute();
      expect(voiceNotifier.state.isMuted, isFalse);
      expect(mockSpeechService.isListening, isTrue);
    });

    test('toggleSubtitles toggles subtitle visibility flag', () {
      expect(voiceNotifier.state.showSubtitles, isTrue);
      voiceNotifier.toggleSubtitles();
      expect(voiceNotifier.state.showSubtitles, isFalse);
      voiceNotifier.toggleSubtitles();
      expect(voiceNotifier.state.showSubtitles, isTrue);
    });

    test('endCall stops listening, cancels playback, and resets state to idle', () async {
      await voiceNotifier.startCall(withGreeting: false);
      expect(voiceNotifier.state.phase, VoiceCallPhase.listening);

      await voiceNotifier.endCall();
      expect(voiceNotifier.state.phase, VoiceCallPhase.idle);
      expect(mockSpeechService.isListening, isFalse);
      expect(audioQueueService.isPlaying, isFalse);
    });
  });
}
