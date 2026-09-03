import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/audio_queue_service.dart';
import '../../core/services/speech_service.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../data/repositories/memory_repository_impl.dart';
import '../../data/repositories/space_repository_impl.dart';
import '../../data/repositories/user_repository_impl.dart';
import '../../domain/models/memory_item.dart';
import '../../domain/models/user.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/repositories/memory_repository.dart';
import '../../domain/repositories/space_repository.dart';
import '../../domain/repositories/user_repository.dart';
import 'chat_notifier.dart';
import 'memory_notifier.dart';
import 'memory_state.dart';
import 'space_notifier.dart';
import 'space_state.dart';
import 'voice_call_notifier.dart';
import 'voice_call_state.dart';

final spaceRepositoryProvider = Provider<SpaceRepository>((ref) {
  return SpaceRepositoryImpl();
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepositoryImpl();
});

final userProfileProvider = FutureProvider<UserModel>((ref) async {
  final repository = ref.watch(userRepositoryProvider);
  return repository.getUserProfile();
});

final spaceProvider =
    StateNotifierProvider<SpaceNotifier, SpaceState>((ref) {
  final repository = ref.watch(spaceRepositoryProvider);
  return SpaceNotifier(repository);
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final repository = ChatRepositoryImpl();
  ref.onDispose(() => repository.dispose());
  return repository;
});

final memoryRepositoryProvider = Provider<MemoryRepository>((ref) {
  return MemoryRepositoryImpl();
});

final audioQueueServiceProvider = Provider<AudioQueueService>((ref) {
  final service = AudioQueueService();
  ref.onDispose(() => service.dispose());
  return service;
});

final speechServiceProvider = Provider<BaseSpeechService>((ref) {
  return SpeechService();
});

final memoryProvider =
    StateNotifierProvider<MemoryNotifier, MemoryState>((ref) {
  final repository = ref.watch(memoryRepositoryProvider);
  return MemoryNotifier(repository);
});

final userMemoriesProvider = FutureProvider<List<MemoryItem>>((ref) async {
  final repository = ref.watch(memoryRepositoryProvider);
  return repository.getMemories();
});

final voiceCallProvider =
    StateNotifierProvider.autoDispose<VoiceCallNotifier, VoiceCallState>((ref) {
  final chatNotifier = ref.watch(chatProvider.notifier);
  final speechService = ref.watch(speechServiceProvider);
  final audioQueueService = ref.watch(audioQueueServiceProvider);
  return VoiceCallNotifier(
    chatNotifier: chatNotifier,
    speechService: speechService,
    audioQueueService: audioQueueService,
  );
});
