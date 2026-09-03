import '../../domain/models/trending_article.dart';
import '../../domain/repositories/trending_repository.dart';
import '../datasources/trending_remote_data_source.dart';

class TrendingRepositoryImpl implements TrendingRepository {
  final TrendingRemoteDataSource _remoteDataSource;

  TrendingRepositoryImpl({TrendingRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? TrendingRemoteDataSource();

  @override
  Future<List<TrendingArticleModel>> getArticles({
    String? category,
    int? limit,
  }) {
    return _remoteDataSource.getArticles(category: category, limit: limit);
  }

  @override
  Future<TrendingArticleModel> getArticle(String id) {
    return _remoteDataSource.getArticle(id);
  }

  @override
  Future<TrendingSyncResult> syncArticles({
    String? category,
    int limitPerCategory = 5,
  }) {
    return _remoteDataSource.syncArticles(
      category: category,
      limitPerCategory: limitPerCategory,
    );
  }
}
