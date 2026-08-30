import 'package:flutter_test/flutter_test.dart';
import 'package:snape_ui/domain/models/memory_item.dart';
import 'package:snape_ui/domain/repositories/memory_repository.dart';
import 'package:snape_ui/presentation/state/memory_notifier.dart';

class MockMemoryRepository implements MemoryRepository {
  List<MemoryItem> items = [];
  bool shouldThrow = false;

  @override
  Future<List<MemoryItem>> getMemories({
    int limit = 50,
    int offset = 0,
    String? category,
  }) async {
    if (shouldThrow) {
      throw Exception('Network error fetching memories');
    }
    if (category != null && category.isNotEmpty) {
      return items
          .where((m) => m.category.toLowerCase() == category.toLowerCase())
          .toList();
    }
    return items;
  }

  @override
  Future<void> deleteMemory(String memoryId) async {
    if (shouldThrow) {
      throw Exception('Network error deleting memory');
    }
    items.removeWhere((m) => m.id == memoryId);
  }
}

void main() {
  group('MemoryNotifier', () {
    late MockMemoryRepository repository;
    late MemoryNotifier notifier;

    final testMemories = [
      MemoryItem(
        id: '1',
        userId: 'u1',
        category: 'fact',
        content: 'User works as a backend engineer.',
        createdAt: DateTime(2026, 8, 30, 9, 0),
      ),
      MemoryItem(
        id: '2',
        userId: 'u1',
        category: 'goal',
        content: 'Prepare for IELTS speaking band 7.5.',
        createdAt: DateTime(2026, 8, 30, 9, 30),
      ),
      MemoryItem(
        id: '3',
        userId: 'u1',
        category: 'preference',
        content: 'Prefers concise grammar explanations.',
        createdAt: DateTime(2026, 8, 30, 10, 0),
      ),
    ];

    setUp(() {
      repository = MockMemoryRepository()..items = List.from(testMemories);
      notifier = MemoryNotifier(repository);
    });

    test('initial load fetches all memories', () async {
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.memories.length, 3);
      expect(notifier.state.filteredMemories.length, 3);
      expect(notifier.state.categorizedMemories['FACT']?.length, 1);
      expect(notifier.state.categorizedMemories['GOAL']?.length, 1);
      expect(notifier.state.categorizedMemories['PREFERENCE']?.length, 1);
    });

    test('selectCategory filters memories correctly and toggles off when re-selected', () async {
      await Future<void>.delayed(Duration.zero);

      notifier.selectCategory('fact');
      expect(notifier.state.selectedCategory, 'fact');
      expect(notifier.state.filteredMemories.length, 1);
      expect(notifier.state.filteredMemories.first.content, 'User works as a backend engineer.');

      // Toggle off
      notifier.selectCategory('fact');
      expect(notifier.state.selectedCategory, isNull);
      expect(notifier.state.filteredMemories.length, 3);
    });

    test('deleteMemory removes item from state list', () async {
      await Future<void>.delayed(Duration.zero);

      final success = await notifier.deleteMemory('2');
      expect(success, isTrue);
      expect(notifier.state.memories.length, 2);
      expect(notifier.state.memories.any((m) => m.id == '2'), isFalse);
    });

    test('handles fetch error gracefully', () async {
      repository.shouldThrow = true;
      await notifier.loadMemories();

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.hasError, isTrue);
      expect(notifier.state.errorMessage, contains('Network error'));
    });
  });
}
