import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

abstract class BaseSpeechService {
  Future<bool> initialize();
  Future<void> startListening({
    required Function(String text, bool isFinal) onResult,
    Function(bool isListening)? onListeningStateChanged,
    String localeId = 'id_ID',
  });
  Future<void> stopListening();
  bool get isListening;
  bool get isAvailable;
}

class SpeechService implements BaseSpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isAvailable = false;
  bool _isListening = false;
  bool _isStarting = false;
  Function(bool isListening)? _onListeningStateChanged;

  @override
  bool get isAvailable => _isAvailable;

  @override
  bool get isListening => _isListening || _speech.isListening || _isStarting;

  @override
  Future<bool> initialize() async {
    try {
      _isAvailable = await _speech.initialize(
        onError: (error) {
          debugPrint('SpeechToText error: $error');
          if (_isListening) {
            _isListening = false;
            _onListeningStateChanged?.call(false);
          }
        },
        onStatus: (status) {
          debugPrint('SpeechToText status: $status');
          if (status == 'notListening' || status == 'done') {
            if (_isListening) {
              _isListening = false;
              _onListeningStateChanged?.call(false);
            }
          } else if (status == 'listening') {
            if (!_isListening) {
              _isListening = true;
              _onListeningStateChanged?.call(true);
            }
          }
        },
      );
      return _isAvailable;
    } catch (e) {
      debugPrint('SpeechToText initialization failed: $e');
      _isAvailable = false;
      _isListening = false;
      return false;
    }
  }

  @override
  Future<void> startListening({
    required Function(String text, bool isFinal) onResult,
    Function(bool isListening)? onListeningStateChanged,
    String localeId = 'id_ID',
    stt.ListenMode listenMode = stt.ListenMode.dictation,
    Duration pauseFor = const Duration(seconds: 4),
  }) async {
    _onListeningStateChanged = onListeningStateChanged;

    if (_isStarting || _speech.isListening) {
      return;
    }

    if (!_isAvailable) {
      final initialized = await initialize();
      if (!initialized) {
        _isListening = false;
        onListeningStateChanged?.call(false);
        return;
      }
    }

    _isStarting = true;
    try {
      if (_speech.isListening) {
        await _speech.stop();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      await _speech.listen(
        onResult: (result) {
          onResult(result.recognizedWords, result.finalResult);
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: listenMode,
          pauseFor: pauseFor,
          localeId: localeId,
          cancelOnError: false,
          partialResults: true,
        ),
      );
    } catch (e) {
      debugPrint('Speech listening error: $e');
      _isListening = false;
      onListeningStateChanged?.call(false);
    } finally {
      _isStarting = false;
    }
  }

  @override
  Future<void> stopListening() async {
    try {
      _isStarting = false;
      if (_speech.isListening) {
        await _speech.stop();
      }
      if (_isListening) {
        _isListening = false;
        _onListeningStateChanged?.call(false);
      }
    } catch (e) {
      debugPrint('Speech stop error: $e');
      _isListening = false;
    }
  }
}
