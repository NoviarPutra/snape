import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/memory_repository.dart';
import 'memory_state.dart';

class MemoryNotifier extends StateNotifier<MemoryState> {
  final MemoryRepository _repository;

  MemoryNotifier(this._repository) : super(const MemoryState()) {
    loadMemories();
  }

  Future<void> loadMemories({String? category}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final memories = await _repository.getMemories(category: category);
      state = state.copyWith(
        memories: memories,
        isLoading: false,
        selectedCategory: category,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load memories: $e',
      );
    }
  }

  Future<void> refresh() async {
    await loadMemories(category: state.selectedCategory);
  }

  void selectCategory(String? category) {
    if (state.selectedCategory == category) {
      state = state.copyWith(clearCategory: true);
    } else {
      state = state.copyWith(selectedCategory: category);
    }
  }

  Future<bool> deleteMemory(String memoryId) async {
    try {
      await _repository.deleteMemory(memoryId);
      final updated = state.memories.where((m) => m.id != memoryId).toList();
      state = state.copyWith(memories: updated);
      return true;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Failed to delete memory: $e',
      );
      return false;
    }
  }
}
