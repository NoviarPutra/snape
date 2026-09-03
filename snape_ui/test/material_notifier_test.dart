import 'package:flutter_test/flutter_test.dart';
import 'package:snape_ui/domain/models/material_item.dart';
import 'package:snape_ui/domain/repositories/material_repository.dart';
import 'package:snape_ui/presentation/state/material_notifier.dart';

class MockMaterialRepository implements MaterialRepository {
  final Map<String, String?> materials = {};
  bool shouldThrow = false;
  int callCount = 0;

  @override
  Future<String?> getMaterial(String spaceSlug, String category) async {
    callCount++;
    if (shouldThrow) {
      throw Exception('Network error');
    }
    return materials['$spaceSlug/$category'];
  }
}

void main() {
  group('MaterialNotifier and MaterialState', () {
    late MockMaterialRepository repository;
    late MaterialNotifier notifier;

    setUp(() {
      repository = MockMaterialRepository();
      notifier = MaterialNotifier(repository);
    });

    test('initial state has default cheatsheet category and empty content', () {
      expect(notifier.state.selectedCategory, MaterialCategory.cheatsheet);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.errorMessage, isNull);
      expect(notifier.state.currentContent, isNull);
      expect(notifier.state.isCurrentCategoryLoaded, isFalse);
    });

    test('selectCategory fetches content lazily on first access', () async {
      repository.materials['english_b2/cheatsheet'] = '# B2 Cheatsheet';

      await notifier.selectCategory('english_b2', MaterialCategory.cheatsheet);

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.selectedCategory, MaterialCategory.cheatsheet);
      expect(notifier.state.currentContent, '# B2 Cheatsheet');
      expect(notifier.state.isCurrentCategoryLoaded, true);
      expect(notifier.state.isCurrentCategoryEmpty, false);
      expect(repository.callCount, 1);
    });

    test('selectCategory uses cached content when already loaded for same space', () async {
      repository.materials['english_b2/cheatsheet'] = '# B2 Cheatsheet';
      repository.materials['english_b2/vocab-formal'] = '# B2 Vocab';

      await notifier.selectCategory('english_b2', MaterialCategory.cheatsheet);
      expect(repository.callCount, 1);

      await notifier.selectCategory('english_b2', MaterialCategory.vocabFormal);
      expect(repository.callCount, 2);
      expect(notifier.state.currentContent, '# B2 Vocab');

      // Switch back to cheatsheet -> should not call repository again
      await notifier.selectCategory('english_b2', MaterialCategory.cheatsheet);
      expect(repository.callCount, 2);
      expect(notifier.state.currentContent, '# B2 Cheatsheet');
    });

    test('404 response (null content) marks category as loaded and empty', () async {
      // repository returns null by default for unconfigured keys (simulating 404)
      await notifier.selectCategory('english_a1', MaterialCategory.slang);

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.errorMessage, isNull);
      expect(notifier.state.currentContent, isNull);
      expect(notifier.state.isCurrentCategoryLoaded, true);
      expect(notifier.state.isCurrentCategoryEmpty, true);
    });

    test('error state is set when repository throws', () async {
      repository.shouldThrow = true;

      await notifier.selectCategory('english_b2', MaterialCategory.cheatsheet);

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.errorMessage, contains('Network error'));
      expect(notifier.state.isCurrentCategoryLoaded, false);
    });

    test('switching space invalidates cache and triggers fresh fetch', () async {
      repository.materials['english_b2/cheatsheet'] = '# B2 Cheatsheet';
      repository.materials['english_c1/cheatsheet'] = '# C1 Cheatsheet';

      await notifier.selectCategory('english_b2', MaterialCategory.cheatsheet);
      expect(notifier.state.currentContent, '# B2 Cheatsheet');
      expect(repository.callCount, 1);

      // Now switch space to english_c1
      await notifier.selectCategory('english_c1', MaterialCategory.cheatsheet);
      expect(notifier.state.currentSpaceSlug, 'english_c1');
      expect(notifier.state.currentContent, '# C1 Cheatsheet');
      expect(repository.callCount, 2);
    });

    test('retry reloads current category after error', () async {
      repository.shouldThrow = true;
      await notifier.selectCategory('english_b2', MaterialCategory.cheatsheet);
      expect(notifier.state.errorMessage, isNotNull);

      repository.shouldThrow = false;
      repository.materials['english_b2/cheatsheet'] = '# B2 Cheatsheet Restored';
      await notifier.retry('english_b2');

      expect(notifier.state.errorMessage, isNull);
      expect(notifier.state.currentContent, '# B2 Cheatsheet Restored');
    });
  });
}
