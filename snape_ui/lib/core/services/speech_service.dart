import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

abstract class BaseSpeechService {
  Future<bool> initialize();
  Future<void> startListening({
    required Function(String text, bool isFinal) onResult,
    Function(bool isListening)? onListeningStateChanged,
  });
  Future<void> stopListening();
  bool get isListening;
  bool get isAvailable;
}

class SpeechService implements BaseSpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isAvailable = false;

  @override
  bool get isAvailable => _isAvailable;

  @override
  bool get isListening => _speech.isListening;

  @override
  Future<bool> initialize() async {
    try {
      _isAvailable = await _speech.initialize(
        onError: (error) => debugPrint('SpeechToText error: $error'),
        onStatus: (status) => debugPrint('SpeechToText status: $status'),
      );
      return _isAvailable;
    } catch (e) {
      debugPrint('SpeechToText initialization failed: $e');
      _isAvailable = false;
      return false;
    }
  }

  @override
  Future<void> startListening({
    required Function(String text, bool isFinal) onResult,
    Function(bool isListening)? onListeningStateChanged,
  }) async {
    if (!_isAvailable) {
      final initialized = await initialize();
      if (!initialized) return;
    }

    onListeningStateChanged?.call(true);

    try {
      await _speech.listen(
        onResult: (result) {
          onResult(result.recognizedWords, result.finalResult);
          if (result.finalResult) {
            onListeningStateChanged?.call(false);
          }
        },
        listenMode: stt.ListenMode.dictation,
        localeId: 'en_US',
        pauseFor: const Duration(seconds: 3),
      );
    } catch (e) {
      debugPrint('Speech listening error: $e');
      onListeningStateChanged?.call(false);
    }
  }

  @override
  Future<void> stopListening() async {
    try {
      await _speech.stop();
    } catch (e) {
      debugPrint('Speech stop error: $e');
    }
  }
}
