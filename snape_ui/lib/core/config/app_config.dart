import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  AppConfig._();

  static const String _defaultHost = 'api.103-174-114-224.nip.io';
  static const String _defaultHttpScheme = 'https';
  static const String _defaultWsScheme = 'wss';

  static String get backendHost {
    try {
      if (dotenv.isInitialized) {
        return dotenv.maybeGet('BACKEND_HOST', fallback: _defaultHost) ?? _defaultHost;
      }
      return _defaultHost;
    } catch (_) {
      return _defaultHost;
    }
  }

  static String get httpScheme {
    try {
      if (dotenv.isInitialized) {
        return dotenv.maybeGet('HTTP_SCHEME', fallback: _defaultHttpScheme) ??
            _defaultHttpScheme;
      }
      return _defaultHttpScheme;
    } catch (_) {
      return _defaultHttpScheme;
    }
  }

  static String get wsScheme {
    try {
      if (dotenv.isInitialized) {
        return dotenv.maybeGet('WS_SCHEME', fallback: _defaultWsScheme) ??
            _defaultWsScheme;
      }
      return _defaultWsScheme;
    } catch (_) {
      return _defaultWsScheme;
    }
  }

  static String get baseHttpUrl => '$httpScheme://$backendHost/api/v1';

  static String get baseWsUrl => '$wsScheme://$backendHost/ws/chat';

  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
  };
}
