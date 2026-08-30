import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snape_ui/core/config/app_config.dart';
import 'package:snape_ui/core/constants/api_constants.dart';
import 'package:snape_ui/flavors.dart';

void main() {
  group('Flavors and Environment Configuration Tests', () {
    setUp(() {
      dotenv.clean();
    });

    test('verifies dev flavor defaults and title', () {
      F.appFlavor = Flavor.dev;
      expect(F.name, 'dev');
      expect(F.title, 'Snape Dev');
      expect(F.isDev, isTrue);
      expect(F.isProd, isFalse);
      expect(F.envFileName, '.env.dev');
    });

    test('verifies prod flavor defaults and title', () {
      F.appFlavor = Flavor.prod;
      expect(F.name, 'prod');
      expect(F.title, 'Snape');
      expect(F.isDev, isFalse);
      expect(F.isProd, isTrue);
      expect(F.envFileName, '.env.prod');
    });

    test('uses fallback default values when uninitialized', () {
      expect(AppConfig.backendHost, 'uncontinual-julieann-corymbosely.ngrok-free.dev');
      expect(AppConfig.httpScheme, 'https');
      expect(AppConfig.wsScheme, 'wss');
      expect(AppConfig.baseHttpUrl, 'https://uncontinual-julieann-corymbosely.ngrok-free.dev/api/v1');
      expect(AppConfig.baseWsUrl, 'wss://uncontinual-julieann-corymbosely.ngrok-free.dev/ws/chat');
      expect(ApiConstants.sessionsUrl, 'https://uncontinual-julieann-corymbosely.ngrok-free.dev/api/v1/sessions');
      expect(ApiConstants.memoriesUrl, 'https://uncontinual-julieann-corymbosely.ngrok-free.dev/api/v1/memories');
      expect(
        ApiConstants.sessionMessagesUrl('test-session-123'),
        'https://uncontinual-julieann-corymbosely.ngrok-free.dev/api/v1/sessions/test-session-123',
      );
      expect(
        ApiConstants.chatWsUrl('test-session-123'),
        'wss://uncontinual-julieann-corymbosely.ngrok-free.dev/ws/chat/test-session-123',
      );
    });

    test('dynamically uses merged dev environment values', () async {
      await dotenv.load(
        isOptional: true,
        mergeWith: {
          'BACKEND_HOST': '10.0.2.2:8000',
          'HTTP_SCHEME': 'http',
          'WS_SCHEME': 'ws',
        },
      );

      expect(AppConfig.backendHost, '10.0.2.2:8000');
      expect(AppConfig.httpScheme, 'http');
      expect(AppConfig.wsScheme, 'ws');
      expect(AppConfig.baseHttpUrl, 'http://10.0.2.2:8000/api/v1');
      expect(AppConfig.baseWsUrl, 'ws://10.0.2.2:8000/ws/chat');
      expect(
        ApiConstants.chatWsUrl('session-dev'),
        'ws://10.0.2.2:8000/ws/chat/session-dev',
      );
    });

    test('dynamically uses merged prod environment values', () async {
      await dotenv.load(
        isOptional: true,
        mergeWith: {
          'BACKEND_HOST': 'api.snape.app',
          'HTTP_SCHEME': 'https',
          'WS_SCHEME': 'wss',
        },
      );

      expect(AppConfig.backendHost, 'api.snape.app');
      expect(AppConfig.httpScheme, 'https');
      expect(AppConfig.wsScheme, 'wss');
      expect(AppConfig.baseHttpUrl, 'https://api.snape.app/api/v1');
      expect(AppConfig.baseWsUrl, 'wss://api.snape.app/ws/chat');
      expect(
        ApiConstants.chatWsUrl('session-prod'),
        'wss://api.snape.app/ws/chat/session-prod',
      );
    });
  });
}
