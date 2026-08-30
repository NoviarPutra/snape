import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snape_ui/core/config/app_config.dart';
import 'package:snape_ui/core/constants/api_constants.dart';

void main() {
  group('AppConfig and ApiConstants Dotenv Tests', () {
    setUp(() {
      dotenv.clean();
    });

    test('uses default fallback values when uninitialized', () {
      expect(AppConfig.backendHost, '127.0.0.1:8000');
      expect(AppConfig.httpScheme, 'http');
      expect(AppConfig.wsScheme, 'ws');
      expect(AppConfig.baseHttpUrl, 'http://127.0.0.1:8000/api/v1');
      expect(AppConfig.baseWsUrl, 'ws://127.0.0.1:8000/ws/chat');
      expect(ApiConstants.sessionsUrl, 'http://127.0.0.1:8000/api/v1/sessions');
      expect(ApiConstants.memoriesUrl, 'http://127.0.0.1:8000/api/v1/memories');
      expect(
        ApiConstants.sessionMessagesUrl('test-session-123'),
        'http://127.0.0.1:8000/api/v1/sessions/test-session-123',
      );
      expect(
        ApiConstants.chatWsUrl('test-session-123'),
        'ws://127.0.0.1:8000/ws/chat/test-session-123',
      );
    });

    test('dynamically uses merged custom .env values', () async {
      await dotenv.load(
        isOptional: true,
        mergeWith: {
          'BACKEND_HOST': '10.0.2.2:8000',
          'HTTP_SCHEME': 'https',
          'WS_SCHEME': 'wss',
        },
      );

      expect(AppConfig.backendHost, '10.0.2.2:8000');
      expect(AppConfig.httpScheme, 'https');
      expect(AppConfig.wsScheme, 'wss');
      expect(AppConfig.baseHttpUrl, 'https://10.0.2.2:8000/api/v1');
      expect(AppConfig.baseWsUrl, 'wss://10.0.2.2:8000/ws/chat');
      expect(ApiConstants.sessionsUrl, 'https://10.0.2.2:8000/api/v1/sessions');
      expect(ApiConstants.memoriesUrl, 'https://10.0.2.2:8000/api/v1/memories');
      expect(
        ApiConstants.chatWsUrl('session-xyz'),
        'wss://10.0.2.2:8000/ws/chat/session-xyz',
      );
    });
  });
}
