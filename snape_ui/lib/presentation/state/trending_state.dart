import 'package:flutter/foundation.dart';
import '../../domain/models/trending_article.dart';

@immutable
class TrendingState {
  final List<TrendingArticleModel> articles;
  final String? selectedCategory;
  final bool isLoading;
  final bool isSyncing;
  final String? errorMessage;
  final String? syncStatusMessage;

  const TrendingState({
    this.articles = const [],
    this.selectedCategory,
    this.isLoading = false,
    this.isSyncing = false,
    this.errorMessage,
    this.syncStatusMessage,
  });

  TrendingState copyWith({
    List<TrendingArticleModel>? articles,
    String? selectedCategory,
    bool? isLoading,
    bool? isSyncing,
    String? errorMessage,
    String? syncStatusMessage,
    bool clearError = false,
    bool clearSyncStatus = false,
    bool clearCategory = false,
  }) {
    return TrendingState(
      articles: articles ?? this.articles,
      selectedCategory: clearCategory
          ? null
          : (selectedCategory ?? this.selectedCategory),
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      syncStatusMessage:
          clearSyncStatus ? null : (syncStatusMessage ?? this.syncStatusMessage),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrendingState &&
          runtimeType == other.runtimeType &&
          listEquals(articles, other.articles) &&
          selectedCategory == other.selectedCategory &&
          isLoading == other.isLoading &&
          isSyncing == other.isSyncing &&
          errorMessage == other.errorMessage &&
          syncStatusMessage == other.syncStatusMessage;

  @override
  int get hashCode =>
      articles.hashCode ^
      selectedCategory.hashCode ^
      isLoading.hashCode ^
      isSyncing.hashCode ^
      errorMessage.hashCode ^
      syncStatusMessage.hashCode;
}
