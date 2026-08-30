class ApiConstants {
  ApiConstants._();

  static const String defaultHost = '127.0.0.1:8000';
  static const String baseHttpUrl = 'http://$defaultHost/api/v1';
  static const String baseWsUrl = 'ws://$defaultHost/ws/chat';

  static String sessionMessagesUrl(String sessionId) =>
      '$baseHttpUrl/sessions/$sessionId';
  static String sessionsUrl = '$baseHttpUrl/sessions';
  static String memoriesUrl = '$baseHttpUrl/memories';
  static String memoryDetailUrl(String memoryId) => '$baseHttpUrl/memories/$memoryId';
  static String chatWsUrl(String sessionId, {String? host}) {
    final effectiveHost = host ?? defaultHost;
    return 'ws://$effectiveHost/ws/chat/$sessionId';
  }
}
