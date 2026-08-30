import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/audio_queue_service.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../data/repositories/memory_repository_impl.dart';
import '../../domain/models/memory_item.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/repositories/memory_repository.dart';
import 'memory_notifier.dart';
import 'memory_state.dart';

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

final memoryProvider =
    StateNotifierProvider<MemoryNotifier, MemoryState>((ref) {
  final repository = ref.watch(memoryRepositoryProvider);
  return MemoryNotifier(repository);
});

final userMemoriesProvider = FutureProvider<List<MemoryItem>>((ref) async {
  final repository = ref.watch(memoryRepositoryProvider);
  return repository.getMemories();
});
