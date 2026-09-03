import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/trending_repository.dart';
import 'trending_state.dart';

class TrendingNotifier extends StateNotifier<TrendingState> {
  final TrendingRepository _repository;

  TrendingNotifier(this._repository) : super(const TrendingState());

  Future<void> loadArticles({
    String? category,
    bool refresh = false,
  }) async {
    final effectiveCategory = category ?? state.selectedCategory;
    if (!refresh && state.articles.isNotEmpty && state.selectedCategory == effectiveCategory) {
      return;
    }

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      selectedCategory: effectiveCategory,
    );

    try {
      final articles = await _repository.getArticles(
        category: effectiveCategory,
      );
      state = state.copyWith(
        articles: articles,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load trending articles: $e',
      );
    }
  }

  Future<void> selectCategory(String? category) async {
    final normalized = (category == null || category.isEmpty || category.toLowerCase() == 'all')
        ? null
        : category;

    if (state.selectedCategory == normalized && state.articles.isNotEmpty) {
      return;
    }

    state = state.copyWith(
      selectedCategory: normalized,
      clearCategory: normalized == null,
    );
    await loadArticles(category: normalized, refresh: true);
  }

  Future<void> syncArticles({
    String? category,
    int limitPerCategory = 5,
  }) async {
    state = state.copyWith(
      isSyncing: true,
      clearError: true,
      clearSyncStatus: true,
    );

    try {
      final result = await _repository.syncArticles(
        category: category ?? state.selectedCategory,
        limitPerCategory: limitPerCategory,
      );

      final message = 'Synced ${result.syncedCount} new articles';
      state = state.copyWith(
        isSyncing: false,
        syncStatusMessage: message,
      );

      // Refresh list to display newly discovered articles
      await loadArticles(refresh: true);
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        errorMessage: 'Failed to sync trends: $e',
      );
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void clearSyncStatus() {
    state = state.copyWith(clearSyncStatus: true);
  }
}
