import 'package:flutter_test/flutter_test.dart';
import 'package:snape_ui/data/datasources/trending_remote_data_source.dart';
import 'package:snape_ui/domain/models/trending_article.dart';
import 'package:snape_ui/domain/repositories/trending_repository.dart';
import 'package:snape_ui/presentation/state/trending_notifier.dart';

class FakeTrendingRepository implements TrendingRepository {
  List<TrendingArticleModel> articles = [];
  bool shouldThrow = false;
  int syncCallCount = 0;

  @override
  Future<List<TrendingArticleModel>> getArticles({
    String? category,
    int? limit,
  }) async {
    if (shouldThrow) {
      throw Exception('Database error');
    }
    if (category != null && category.isNotEmpty) {
      return articles.where((a) => a.category == category).toList();
    }
    return articles;
  }

  @override
  Future<TrendingArticleModel> getArticle(String id) async {
    if (shouldThrow) {
      throw Exception('Database error');
    }
    return articles.firstWhere((a) => a.id == id);
  }

  @override
  Future<TrendingSyncResult> syncArticles({
    String? category,
    int limitPerCategory = 5,
  }) async {
    if (shouldThrow) {
      throw Exception('Sync failed');
    }
    syncCallCount++;
    return const TrendingSyncResult(
      status: 'success',
      syncedCount: 2,
      categories: ['general'],
      errors: [],
    );
  }
}

void main() {
  group('TrendingNotifier', () {
    late FakeTrendingRepository repository;
    late TrendingNotifier notifier;

    final sampleArticles = [
      TrendingArticleModel(
        id: '1',
        category: 'politics',
        title: 'New Policy Act',
        summary: '- Key point 1\nWhy It\'s Trending: Big change',
        sourceUrl: 'https://example.com/pol',
        publishedAt: DateTime.parse('2026-09-03T00:00:00Z'),
        tags: const ['policy'],
        metadata: const {},
        createdAt: DateTime.parse('2026-09-03T00:00:00Z'),
      ),
      TrendingArticleModel(
        id: '2',
        category: 'creator_trends',
        title: 'Streaming Record Broken',
        summary: '- Massive audience\nWhy It\'s Trending: New record',
        sourceUrl: 'https://example.com/creator',
        publishedAt: DateTime.parse('2026-09-03T00:00:00Z'),
        tags: const ['stream'],
        metadata: const {},
        createdAt: DateTime.parse('2026-09-03T00:00:00Z'),
      ),
    ];

    setUp(() {
      repository = FakeTrendingRepository()..articles = sampleArticles;
      notifier = TrendingNotifier(repository);
    });

    test('initial state is empty and not loading', () {
      expect(notifier.state.articles, isEmpty);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.isSyncing, isFalse);
      expect(notifier.state.selectedCategory, isNull);
    });

    test('loadArticles updates state with fetched articles', () async {
      await notifier.loadArticles();
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.articles.length, equals(2));
      expect(notifier.state.errorMessage, isNull);
    });

    test('selectCategory filters articles and updates category state', () async {
      await notifier.selectCategory('politics');
      expect(notifier.state.selectedCategory, equals('politics'));
      expect(notifier.state.articles.length, equals(1));
      expect(notifier.state.articles.first.category, equals('politics'));

      await notifier.selectCategory(null);
      expect(notifier.state.selectedCategory, isNull);
      expect(notifier.state.articles.length, equals(2));
    });

    test('syncArticles performs sync and refreshes list', () async {
      await notifier.syncArticles();
      expect(repository.syncCallCount, equals(1));
      expect(notifier.state.isSyncing, isFalse);
      expect(notifier.state.syncStatusMessage, contains('Synced 2 new articles'));
      expect(notifier.state.articles.length, equals(2));
    });

    test('handles errors gracefully in loadArticles and syncArticles', () async {
      repository.shouldThrow = true;
      await notifier.loadArticles(refresh: true);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.errorMessage, contains('Database error'));

      await notifier.syncArticles();
      expect(notifier.state.isSyncing, isFalse);
      expect(notifier.state.errorMessage, contains('Sync failed'));
    });
  });
}
