import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';
import '../../core/constants/api_constants.dart';
import '../../domain/models/trending_article.dart';

class TrendingSyncResult {
  final String status;
  final int syncedCount;
  final List<String> categories;
  final List<String> errors;

  const TrendingSyncResult({
    required this.status,
    required this.syncedCount,
    this.categories = const [],
    this.errors = const [],
  });

  factory TrendingSyncResult.fromJson(Map<String, dynamic> json) {
    return TrendingSyncResult(
      status: (json['status'] as String?) ?? 'success',
      syncedCount: (json['synced_count'] as int?) ??
          (json['syncedCount'] as int?) ??
          0,
      categories: (json['categories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      errors: (json['errors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

class TrendingRemoteDataSource {
  final http.Client _client;

  TrendingRemoteDataSource({
    http.Client? client,
    String? baseHttpUrl,
  })  : _client = client ?? http.Client();

  Future<List<TrendingArticleModel>> getArticles({
    String? category,
    int? limit,
  }) async {
    final url = ApiConstants.trendingArticlesUrl(
      category: category,
      limit: limit,
    );
    final response = await _client.get(
      Uri.parse(url),
      headers: AppConfig.defaultHeaders,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final List<dynamic> list = json.decode(response.body) as List<dynamic>;
      return list
          .map((item) =>
              TrendingArticleModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception(
        'Failed to load trending articles: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<TrendingArticleModel> getArticle(String articleId) async {
    final url = ApiConstants.trendingArticleDetailUrl(articleId);
    final response = await _client.get(
      Uri.parse(url),
      headers: AppConfig.defaultHeaders,
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final jsonMap = json.decode(response.body) as Map<String, dynamic>;
      return TrendingArticleModel.fromJson(jsonMap);
    } else {
      throw Exception(
        'Failed to load article detail: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<TrendingSyncResult> syncArticles({
    String? category,
    int limitPerCategory = 5,
  }) async {
    final url = ApiConstants.trendingSyncUrl;
    final payload = <String, dynamic>{
      'limit_per_category': limitPerCategory,
    };
    if (category != null && category.isNotEmpty && category.toLowerCase() != 'all') {
      payload['category'] = category;
    }

    final response = await _client.post(
      Uri.parse(url),
      headers: AppConfig.defaultHeaders,
      body: json.encode(payload),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final jsonMap = json.decode(response.body) as Map<String, dynamic>;
      return TrendingSyncResult.fromJson(jsonMap);
    } else {
      throw Exception(
        'Failed to sync trending articles: ${response.statusCode} ${response.body}',
      );
    }
  }
}
