import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/audio_queue_service.dart';
import '../../core/services/speech_service.dart';
import 'chat_notifier.dart';
import 'chat_state.dart';
import 'voice_call_state.dart';

class VoiceCallNotifier extends StateNotifier<VoiceCallState> {
  final ChatNotifier chatNotifier;
  final BaseSpeechService speechService;
  final AudioQueueService? audioQueueService;
  final Duration silenceDuration;

  Timer? _silenceTimer;
  StreamSubscription<bool>? _isSpeakingSubscription;
  VoidCallback? _chatRemoveListener;

  VoiceCallNotifier({
    required this.chatNotifier,
    required this.speechService,
    this.audioQueueService,
    this.silenceDuration = const Duration(milliseconds: 1800),
  }) : super(const VoiceCallState()) {
    _initSubscriptions();
  }

  void _initSubscriptions() {
    _isSpeakingSubscription =
        audioQueueService?.isSpeakingStream.listen((isSpeaking) {
      if (isSpeaking) {
        if (state.phase != VoiceCallPhase.idle) {
          state = state.copyWith(phase: VoiceCallPhase.speaking);
        }
      } else {
        // When AI stops speaking and we are in an active call, return to listening
        if (state.phase == VoiceCallPhase.speaking ||
            state.phase == VoiceCallPhase.greeting) {
          if (!state.isMuted && state.phase != VoiceCallPhase.idle) {
            _startListeningLoop();
          }
        }
      }
    });

    _chatRemoveListener = chatNotifier.addListener(_handleChatStateChange);
  }

  void _handleChatStateChange(ChatState chatState) {
    if (state.phase == VoiceCallPhase.idle) return;

    if (chatState.isStreaming && chatState.currentStreamingId.isNotEmpty) {
      final streamingMsg = chatState.messages
          .where((m) => m.id == chatState.currentStreamingId)
          .firstOrNull;
      if (streamingMsg != null) {
        state = state.copyWith(
          assistantSpeech: streamingMsg.content,
        );
      }
    }
  }

  Future<void> startCall({
    bool withGreeting = true,
    String? greetingText,
  }) async {
    final available = await speechService.initialize();
    if (!available) {
      state = state.copyWith(
        errorMessage: 'Microphone / Speech recognition is not available.',
      );
      return;
    }

    if (withGreeting) {
      final greeting = greetingText ??
          "Hey there! It's great to hear from you. What's on your mind today?";
      state = state.copyWith(
        phase: VoiceCallPhase.greeting,
        assistantSpeech: greeting,
        userSpeech: '',
        clearError: true,
      );
      await _startListeningLoop(keepPhase: true);
    } else {
      state = state.copyWith(
        phase: VoiceCallPhase.listening,
        userSpeech: '',
        clearError: true,
      );
      await _startListeningLoop();
    }
  }

  Future<void> _startListeningLoop({bool keepPhase = false}) async {
    if (state.isMuted || state.phase == VoiceCallPhase.idle) return;

    _silenceTimer?.cancel();
    if (!keepPhase) {
      state = state.copyWith(
        phase: VoiceCallPhase.listening,
        userSpeech: '',
        clearError: true,
      );
    }

    await speechService.startListening(
      localeId: state.localeId,
      onResult: (text, isFinal) {
        _handleSpeechResult(text, isFinal);
      },
      onListeningStateChanged: (isListening) {
        if (!isListening &&
            (state.phase == VoiceCallPhase.listening ||
                state.phase == VoiceCallPhase.greeting) &&
            state.userSpeech.trim().isNotEmpty) {
          _dispatchUserTurn();
        }
      },
    );
  }

  void _handleSpeechResult(String text, bool isFinal) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    // Barge-in: If user speaks while AI is speaking or in greeting, interrupt immediately
    if (state.phase == VoiceCallPhase.speaking ||
        state.phase == VoiceCallPhase.greeting) {
      bargeIn();
    }

    state = state.copyWith(
      phase: VoiceCallPhase.listening,
      userSpeech: trimmed,
    );
    _silenceTimer?.cancel();

    if (isFinal) {
      _dispatchUserTurn();
    } else {
      // Reset silence debounce timer
      _silenceTimer = Timer(silenceDuration, () {
        if (state.phase == VoiceCallPhase.listening &&
            state.userSpeech.trim().isNotEmpty) {
          _dispatchUserTurn();
        }
      });
    }
  }

  void _dispatchUserTurn() {
    _silenceTimer?.cancel();
    final textToSend = state.userSpeech.trim();
    if (textToSend.isEmpty || state.phase == VoiceCallPhase.thinking) return;

    state = state.copyWith(
      phase: VoiceCallPhase.thinking,
      assistantSpeech: '',
    );
    speechService.stopListening();

    chatNotifier.sendMessage(textToSend);
  }

  void bargeIn() {
    _silenceTimer?.cancel();
    audioQueueService?.stopAndClear();
    state = state.copyWith(
      phase: VoiceCallPhase.listening,
      assistantSpeech: '',
    );
    _startListeningLoop();
  }

  Future<void> toggleLanguage() async {
    final newLocale = state.localeId == 'en_US' ? 'id_ID' : 'en_US';
    state = state.copyWith(localeId: newLocale);

    if (state.phase == VoiceCallPhase.listening && !state.isMuted) {
      await speechService.stopListening();
      await _startListeningLoop();
    }
  }

  Future<void> toggleMute() async {
    final newMute = !state.isMuted;
    state = state.copyWith(isMuted: newMute);

    if (newMute) {
      _silenceTimer?.cancel();
      await speechService.stopListening();
    } else {
      if (state.phase == VoiceCallPhase.listening ||
          state.phase == VoiceCallPhase.idle) {
        state = state.copyWith(phase: VoiceCallPhase.listening);
        await _startListeningLoop();
      }
    }
  }

  void toggleSubtitles() {
    state = state.copyWith(showSubtitles: !state.showSubtitles);
  }

  Future<void> endCall() async {
    _silenceTimer?.cancel();
    await speechService.stopListening();
    audioQueueService?.stopAndClear();

    state = state.copyWith(
      phase: VoiceCallPhase.idle,
      userSpeech: '',
      assistantSpeech: '',
    );
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _isSpeakingSubscription?.cancel();
    _chatRemoveListener?.call();
    speechService.stopListening();
    super.dispose();
  }
}
