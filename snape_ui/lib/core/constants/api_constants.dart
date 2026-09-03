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
  static String chatWsUrl(String sessionId, {String? host}) {
    final effectiveHost = host ?? defaultHost;
    return '${AppConfig.wsScheme}://$effectiveHost/ws/chat/$sessionId';
  }
}
