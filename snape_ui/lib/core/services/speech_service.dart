import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

abstract class BaseSpeechService {
  Future<bool> initialize();
  Future<void> startListening({
    required Function(String text, bool isFinal) onResult,
    Function(bool isListening)? onListeningStateChanged,
    String localeId = 'en_US',
  });
  Future<void> stopListening();
  bool get isListening;
  bool get isAvailable;
}

class SpeechService implements BaseSpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isAvailable = false;
  Function(bool isListening)? _onListeningStateChanged;

  @override
  bool get isAvailable => _isAvailable;

  @override
  bool get isListening => _speech.isListening;

  @override
  Future<bool> initialize() async {
    try {
      _isAvailable = await _speech.initialize(
        onError: (error) {
          debugPrint('SpeechToText error: $error');
          _onListeningStateChanged?.call(false);
        },
        onStatus: (status) {
          debugPrint('SpeechToText status: $status');
          if (status == 'notListening' || status == 'done') {
            _onListeningStateChanged?.call(false);
          } else if (status == 'listening') {
            _onListeningStateChanged?.call(true);
          }
        },
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
    String localeId = 'en_US',
  }) async {
    _onListeningStateChanged = onListeningStateChanged;

    if (!_isAvailable) {
      final initialized = await initialize();
      if (!initialized) {
        onListeningStateChanged?.call(false);
        return;
      }
    }

    if (_speech.isListening) {
      return;
    }

    try {
      await _speech.listen(
        onResult: (result) {
          onResult(result.recognizedWords, result.finalResult);
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.confirmation,
          pauseFor: const Duration(seconds: 3),
          localeId: localeId,
          cancelOnError: false,
          partialResults: true,
        ),
      );
    } catch (e) {
      debugPrint('Speech listening error: $e');
      onListeningStateChanged?.call(false);
    }
  }

  @override
  Future<void> stopListening() async {
    try {
      if (_speech.isListening) {
        await _speech.stop();
      }
    } catch (e) {
      debugPrint('Speech stop error: $e');
    }
  }
}
