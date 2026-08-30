import 'package:flutter/foundation.dart';
import '../../domain/models/memory_item.dart';

@immutable
class MemoryState {
  final List<MemoryItem> memories;
  final bool isLoading;
  final String? errorMessage;
  final String? selectedCategory;

  const MemoryState({
    this.memories = const [],
    this.isLoading = false,
    this.errorMessage,
    this.selectedCategory,
  });

  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;

  List<MemoryItem> get filteredMemories {
    if (selectedCategory == null || selectedCategory!.isEmpty) {
      return memories;
    }
    return memories
        .where((m) =>
            m.category.toLowerCase() == selectedCategory!.toLowerCase())
        .toList();
  }

  Map<String, List<MemoryItem>> get categorizedMemories {
    final Map<String, List<MemoryItem>> categorized = {
      'FACT': [],
      'PREFERENCE': [],
      'GOAL': [],
      'EXPERIENCE': [],
      'OTHER': [],
    };

    for (final memory in memories) {
      final cat = memory.category.toUpperCase();
      if (categorized.containsKey(cat)) {
        categorized[cat]!.add(memory);
      } else {
        categorized['OTHER']!.add(memory);
      }
    }
    return categorized;
  }

  MemoryState copyWith({
    List<MemoryItem>? memories,
    bool? isLoading,
    String? errorMessage,
    String? selectedCategory,
    bool clearCategory = false,
    bool clearError = false,
  }) {
    return MemoryState(
      memories: memories ?? this.memories,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      selectedCategory:
          clearCategory ? null : (selectedCategory ?? this.selectedCategory),
    );
  }
}
