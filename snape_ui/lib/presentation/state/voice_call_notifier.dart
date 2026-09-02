import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  Timer? _restartTimer;
  Timer? _audioDoneDebounceTimer;
  StreamSubscription<bool>? _isSpeakingSubscription;
  VoidCallback? _chatRemoveListener;

  bool _isDispatching = false;
  String _lastDispatchedText = '';
  DateTime? _lastDispatchTime;

  VoiceCallNotifier({
    required this.chatNotifier,
    required this.speechService,
    this.audioQueueService,
    this.silenceDuration = const Duration(milliseconds: 2200),
  }) : super(const VoiceCallState()) {
    SharedPreferences.getInstance().then((prefs) {
      final saved = prefs.getString('stt_locale') ?? 'id_ID';
      if (saved != state.localeId && mounted) {
        state = state.copyWith(localeId: saved);
      }
    });
    _initSubscriptions();
  }

  void _initSubscriptions() {
    _isSpeakingSubscription =
        audioQueueService?.isSpeakingStream.listen((isSpeaking) {
      if (isSpeaking) {
        _audioDoneDebounceTimer?.cancel();
        _silenceTimer?.cancel();
        _restartTimer?.cancel();
        speechService.stopListening();
        if (state.phase != VoiceCallPhase.idle) {
          state = state.copyWith(phase: VoiceCallPhase.speaking);
        }
      } else {
        // When AI stops speaking and we are in an active call, return to listening after acoustic delay
        if (state.phase == VoiceCallPhase.speaking ||
            state.phase == VoiceCallPhase.greeting ||
            state.phase == VoiceCallPhase.thinking) {
          if (!state.isMuted && state.phase != VoiceCallPhase.idle) {
            _audioDoneDebounceTimer?.cancel();
            _audioDoneDebounceTimer =
                Timer(const Duration(milliseconds: 250), () {
              if (mounted &&
                  !state.isMuted &&
                  state.phase != VoiceCallPhase.idle &&
                  !(audioQueueService?.isSpeaking ?? false)) {
                _startListeningLoop();
              }
            });
          }
        }
      }
    });

    _chatRemoveListener = chatNotifier.addListener(_handleChatStateChange);
  }

  void _handleChatStateChange(ChatState chatState) {
    if (state.phase == VoiceCallPhase.idle) return;

    if (chatState.errorMessage != null && chatState.errorMessage!.isNotEmpty) {
      _isDispatching = false;
      state = state.copyWith(
        errorMessage: chatState.errorMessage,
        phase: VoiceCallPhase.listening,
      );
      if (!state.isMuted) {
        _startListeningLoop();
      }
      return;
    }

    if (chatState.isStreaming && chatState.currentStreamingId.isNotEmpty) {
      final streamingMsg = chatState.messages
          .where((m) => m.id == chatState.currentStreamingId)
          .firstOrNull;
      if (streamingMsg != null) {
        state = state.copyWith(
          assistantSpeech: streamingMsg.content,
        );
      }
    } else if (!chatState.isStreaming && state.phase == VoiceCallPhase.thinking) {
      final hasAudioQueuedOrPlaying =
          (audioQueueService?.isPlaying ?? false) ||
          (audioQueueService?.queueLength ?? 0) > 0 ||
          (audioQueueService?.isSpeaking ?? false);
      if (!hasAudioQueuedOrPlaying && !state.isMuted) {
        _isDispatching = false;
        _startListeningLoop();
      }
    }
  }

  Future<void> startCall({
    bool withGreeting = true,
    String? greetingText,
  }) async {
    chatNotifier.setAutoplayAudio(true);
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
    if (!mounted || state.isMuted || state.phase == VoiceCallPhase.idle) return;
    if (audioQueueService?.isSpeaking ?? false) return;

    _silenceTimer?.cancel();
    _restartTimer?.cancel();
    _isDispatching = false;

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
        if (!isListening && mounted) {
          if (state.phase == VoiceCallPhase.listening ||
              state.phase == VoiceCallPhase.greeting) {
            if (!_isDispatching && state.userSpeech.trim().isNotEmpty) {
              _dispatchUserTurn();
            } else if (!state.isMuted &&
                !_isDispatching &&
                state.phase != VoiceCallPhase.idle &&
                state.phase != VoiceCallPhase.thinking &&
                state.phase != VoiceCallPhase.speaking &&
                !(audioQueueService?.isSpeaking ?? false)) {
              _restartTimer?.cancel();
              _restartTimer = Timer(const Duration(milliseconds: 200), () {
                if (mounted &&
                    !state.isMuted &&
                    !_isDispatching &&
                    !(audioQueueService?.isSpeaking ?? false) &&
                    (state.phase == VoiceCallPhase.listening ||
                        state.phase == VoiceCallPhase.greeting)) {
                  _startListeningLoop(keepPhase: true);
                }
              });
            }
          }
        }
      },
    );
  }

  void _handleSpeechResult(String text, bool isFinal) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (_isDispatching || state.phase == VoiceCallPhase.thinking) return;

    // Barge-in: If user speaks while AI is speaking or in greeting, interrupt audio immediately
    if (state.phase == VoiceCallPhase.speaking ||
        state.phase == VoiceCallPhase.greeting) {
      audioQueueService?.stopAndClear();
      state = state.copyWith(
        phase: VoiceCallPhase.listening,
        assistantSpeech: '',
      );
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
        if (!_isDispatching &&
            state.phase == VoiceCallPhase.listening &&
            state.userSpeech.trim().isNotEmpty) {
          _dispatchUserTurn();
        }
      });
    }
  }

  void _dispatchUserTurn() {
    _silenceTimer?.cancel();
    _restartTimer?.cancel();
    if (_isDispatching) return;

    final textToSend = state.userSpeech.trim();
    if (textToSend.isEmpty || state.phase == VoiceCallPhase.thinking) return;

    final now = DateTime.now();
    if (_lastDispatchedText == textToSend &&
        _lastDispatchTime != null &&
        now.difference(_lastDispatchTime!).inMilliseconds < 1500) {
      return;
    }

    _isDispatching = true;
    _lastDispatchedText = textToSend;
    _lastDispatchTime = now;

    if (chatNotifier.state.sessionId == null) {
      _isDispatching = false;
      state = state.copyWith(
        errorMessage: 'No active session found. Please reconnect or open a session.',
        phase: VoiceCallPhase.listening,
      );
      if (!state.isMuted) {
        _startListeningLoop();
      }
      return;
    }

    state = state.copyWith(
      phase: VoiceCallPhase.thinking,
      assistantSpeech: '',
      userSpeech: textToSend,
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
    if (!speechService.isListening && !state.isMuted && state.phase != VoiceCallPhase.idle) {
      _startListeningLoop();
    }
  }

  Future<void> toggleLanguage() async {
    final newLocale = state.localeId == 'en_US' ? 'id_ID' : 'en_US';
    state = state.copyWith(localeId: newLocale);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('stt_locale', newLocale);
    });

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
    chatNotifier.setAutoplayAudio(false);
    _silenceTimer?.cancel();
    _restartTimer?.cancel();
    _audioDoneDebounceTimer?.cancel();
    _isDispatching = false;
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
    chatNotifier.setAutoplayAudio(false);
    _isSpeakingSubscription?.cancel();
    _chatRemoveListener?.call();
    speechService.stopListening();
    audioQueueService?.stopAndClear();
    _silenceTimer?.cancel();
    _restartTimer?.cancel();
    _audioDoneDebounceTimer?.cancel();
    _isDispatching = false;
    super.dispose();
  }
}
