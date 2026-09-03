import '../config/app_config.dart';

class ApiConstants {
  ApiConstants._();

  static String get defaultHost => AppConfig.backendHost;
  static String get baseHttpUrl => AppConfig.baseHttpUrl;
  static String get baseWsUrl => AppConfig.baseWsUrl;

  static String sessionMessagesUrl(String sessionId) =>
      '$baseHttpUrl/sessions/$sessionId';
  static String get sessionsUrl => '$baseHttpUrl/sessions';
  static String get spacesUrl => '$baseHttpUrl/spaces';
  static String get userUrl => '$baseHttpUrl/user';
  static String get ttsSynthesizeUrl => '$baseHttpUrl/tts/synthesize';
  static String get memoriesUrl => '$baseHttpUrl/memories';
  static String memoryDetailUrl(String memoryId) => '$baseHttpUrl/memories/$memoryId';
  static String materialsUrl(String spaceSlug, String category) =>
      '$baseHttpUrl/materials/$spaceSlug/$category';
  static String trendingArticlesUrl({String? category, int? limit}) {
    final queryParams = <String>[];
    if (category != null &&
        category.isNotEmpty &&
        category.toLowerCase() != 'all') {
      queryParams.add('category=${Uri.encodeQueryComponent(category)}');
    }
    if (limit != null && limit > 0) {
      queryParams.add('limit=$limit');
    }
    if (queryParams.isEmpty) {
      return '$baseHttpUrl/trending';
    }
    return '$baseHttpUrl/trending?${queryParams.join('&')}';
  }

  static String trendingArticleDetailUrl(String articleId) =>
      '$baseHttpUrl/trending/$articleId';
  static String get trendingSyncUrl => '$baseHttpUrl/trending/sync';
  static String chatWsUrl(String sessionId, {String? host}) {
    final effectiveHost = host ?? defaultHost;
    return '${AppConfig.wsScheme}://$effectiveHost/ws/chat/$sessionId';
  }
}
