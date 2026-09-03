import '../../data/datasources/trending_remote_data_source.dart';
import '../models/trending_article.dart';

abstract class TrendingRepository {
  Future<List<TrendingArticleModel>> getArticles({
    String? category,
    int? limit,
  });

  Future<TrendingArticleModel> getArticle(String id);

  Future<TrendingSyncResult> syncArticles({
    String? category,
    int limitPerCategory = 5,
  });
}
