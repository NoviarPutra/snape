import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:snape_ui/core/services/audio_queue_service.dart';

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

void main() {
  group('AudioQueueService', () {
    late MockAudioPlayerAdapter mockAdapter;
    late AudioQueueService service;

    setUp(() {
      mockAdapter = MockAudioPlayerAdapter();
      service = AudioQueueService(playerAdapter: mockAdapter);
    });

    tearDown(() async {
      await service.dispose();
    });

    test('enqueues and plays first chunk immediately', () async {
      final chunk1 = Uint8List.fromList([1, 2, 3, 4]);
      final base64Chunk = base64Encode(chunk1);

      service.enqueueBase64(base64Chunk);
      await Future<void>.delayed(Duration.zero);

      expect(service.isPlaying, isTrue);
      expect(service.isSpeaking, isTrue);
      expect(mockAdapter.playedChunks.length, 1);
      expect(mockAdapter.playedChunks.first, equals(chunk1));
    });

    test('plays sequential chunks without overlap on completion events', () async {
      final chunk1 = Uint8List.fromList([1, 2, 3]);
      final chunk2 = Uint8List.fromList([4, 5, 6]);

      service.enqueueBytes(chunk1);
      service.enqueueBytes(chunk2);
      await Future<void>.delayed(Duration.zero);

      expect(mockAdapter.playedChunks.length, 1);
      expect(service.queueLength, 1);

      // Simulate first chunk completion
      mockAdapter.completeCurrentPlayback();
      await Future<void>.delayed(Duration.zero);

      expect(mockAdapter.playedChunks.length, 2);
      expect(mockAdapter.playedChunks[1], equals(chunk2));
      expect(service.queueLength, 0);

      // Simulate second chunk completion
      mockAdapter.completeCurrentPlayback();
      await Future<void>.delayed(Duration.zero);

      expect(service.isPlaying, isFalse);
      expect(service.isSpeaking, isFalse);
    });

    test('barge-in stopAndClear halts ongoing playback and empties buffer', () async {
      final chunk1 = Uint8List.fromList([10, 20]);
      final chunk2 = Uint8List.fromList([30, 40]);
      final chunk3 = Uint8List.fromList([50, 60]);

      service.enqueueBytes(chunk1);
      service.enqueueBytes(chunk2);
      service.enqueueBytes(chunk3);
      await Future<void>.delayed(Duration.zero);

      expect(service.isPlaying, isTrue);
      expect(service.queueLength, 2);

      // User sends a new message (barge-in)
      await service.stopAndClear();

      expect(service.isPlaying, isFalse);
      expect(service.isSpeaking, isFalse);
      expect(service.queueLength, 0);
      expect(mockAdapter.isStopped, isTrue);
    });

    test('emits isSpeaking stream events accurately', () async {
      final speakingStates = <bool>[];
      final subscription = service.isSpeakingStream.listen(speakingStates.add);

      final chunk = Uint8List.fromList([7, 8, 9]);
      service.enqueueBytes(chunk);
      await Future<void>.delayed(Duration.zero);

      mockAdapter.completeCurrentPlayback();
      await Future<void>.delayed(Duration.zero);

      expect(speakingStates, [true, false]);
      await subscription.cancel();
    });
  });
}
