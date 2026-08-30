import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

abstract class AudioPlayerAdapter {
  Stream<void> get onPlayerComplete;
  Future<void> playBytes(Uint8List bytes, {String mimeType = 'audio/wav'});
  Future<void> stop();
  Future<void> dispose();
}

class DefaultAudioPlayerAdapter implements AudioPlayerAdapter {
  final AudioPlayer _player;

  DefaultAudioPlayerAdapter({AudioPlayer? player})
      : _player = player ?? AudioPlayer();

  @override
  Stream<void> get onPlayerComplete => _player.onPlayerComplete;

  @override
  Future<void> playBytes(Uint8List bytes, {String mimeType = 'audio/wav'}) {
    return _player.play(BytesSource(bytes, mimeType: mimeType));
  }

  @override
  Future<void> stop() {
    return _player.stop();
  }

  @override
  Future<void> dispose() {
    return _player.dispose();
  }
}

class AudioQueueService {
  final AudioPlayerAdapter _playerAdapter;
  final Queue<Uint8List> _queue = Queue<Uint8List>();
  final StreamController<bool> _isSpeakingController =
      StreamController<bool>.broadcast();

  StreamSubscription<void>? _completionSubscription;
  bool _isPlaying = false;
  bool _isSpeaking = false;

  AudioQueueService({AudioPlayerAdapter? playerAdapter})
      : _playerAdapter = playerAdapter ?? DefaultAudioPlayerAdapter() {
    _completionSubscription = _playerAdapter.onPlayerComplete.listen((_) {
      _onChunkCompleted();
    });
  }

  bool get isSpeaking => _isSpeaking;
  bool get isPlaying => _isPlaying;
  int get queueLength => _queue.length;
  Stream<bool> get isSpeakingStream => _isSpeakingController.stream;

  void enqueueBase64(String base64Audio, {String? sentence}) {
    if (base64Audio.trim().isEmpty) return;
    try {
      final cleaned = base64Audio.replaceAll(RegExp(r'\s+'), '');
      final bytes = base64Decode(cleaned);
      enqueueBytes(bytes);
    } catch (e) {
      debugPrint('Failed to decode audio base64: $e');
    }
  }

  void enqueueBytes(Uint8List bytes) {
    if (bytes.isEmpty) return;
    _queue.add(bytes);
    if (!_isPlaying) {
      _playNext();
    }
  }

  Future<void> _playNext() async {
    if (_queue.isEmpty) {
      _isPlaying = false;
      _setSpeaking(false);
      return;
    }

    _isPlaying = true;
    _setSpeaking(true);
    final nextChunk = _queue.removeFirst();
    try {
      await _playerAdapter.playBytes(nextChunk);
    } catch (e) {
      debugPrint('Audio playback error: $e');
      if (_isPlaying) {
        _playNext();
      }
    }
  }

  void _onChunkCompleted() {
    if (!_isPlaying) return;
    _playNext();
  }

  Future<void> stopAndClear() async {
    _queue.clear();
    _isPlaying = false;
    _setSpeaking(false);
    try {
      await _playerAdapter.stop();
    } catch (e) {
      debugPrint('Error stopping audio playback: $e');
    }
  }

  void _setSpeaking(bool value) {
    if (_isSpeaking != value) {
      _isSpeaking = value;
      _isSpeakingController.add(value);
    }
  }

  Future<void> dispose() async {
    await stopAndClear();
    await _completionSubscription?.cancel();
    await _isSpeakingController.close();
    await _playerAdapter.dispose();
  }
}
