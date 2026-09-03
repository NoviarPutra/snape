import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:snape_ui/data/datasources/chat_remote_data_source.dart';
import 'package:snape_ui/data/datasources/space_remote_data_source.dart';
import 'package:snape_ui/data/models/websocket_events.dart';
import 'package:snape_ui/data/repositories/chat_repository_impl.dart';
import 'package:snape_ui/data/repositories/space_repository_impl.dart';
import 'package:snape_ui/domain/models/chat_message.dart';
import 'package:snape_ui/domain/models/memory_item.dart';
import 'package:snape_ui/domain/models/session.dart';
import 'package:snape_ui/domain/models/space.dart';

void main() {
  group('SpaceModel', () {
    test('fromJson and toJson should preserve properties', () {
      final json = {
        'slug': 'english_b2',
        'display_name': 'English Chat (B2)',
        'cefr_level': 'B2',
        'voice_call_enabled': true,
        'tts_enabled': true,
      };

      final space = SpaceModel.fromJson(json);
      expect(space.slug, 'english_b2');
      expect(space.displayName, 'English Chat (B2)');
      expect(space.cefrLevel, 'B2');
      expect(space.voiceCallEnabled, isTrue);
      expect(space.ttsEnabled, isTrue);

      final outJson = space.toJson();
      expect(outJson['slug'], 'english_b2');
      expect(outJson['display_name'], 'English Chat (B2)');
      expect(outJson['cefr_level'], 'B2');
      expect(outJson['voice_call_enabled'], isTrue);
      expect(outJson['tts_enabled'], isTrue);
    });

    test('fromJson handles null cefr_level and camelCase fallbacks', () {
      final json = {
        'slug': 'tech',
        'displayName': 'Technology & Architecture',
        'cefrLevel': null,
        'voiceCallEnabled': false,
        'ttsEnabled': false,
      };

      final space = SpaceModel.fromJson(json);
      expect(space.slug, 'tech');
      expect(space.displayName, 'Technology & Architecture');
      expect(space.cefrLevel, isNull);
      expect(space.voiceCallEnabled, isFalse);
      expect(space.ttsEnabled, isFalse);
    });
  });

  group('MemoryItem', () {
    test('fromJson and toJson should preserve properties', () {
      final now = DateTime.now();
      final json = {
        'id': 'mem-123',
        'user_id': 'user-456',
        'category': 'fact',
        'content': 'User loves hiking in mountains.',
        'created_at': now.toIso8601String(),
      };

      final memory = MemoryItem.fromJson(json);
      expect(memory.id, 'mem-123');
      expect(memory.userId, 'user-456');
      expect(memory.category, 'fact');
      expect(memory.content, 'User loves hiking in mountains.');
      expect(memory.toJson()['category'], 'fact');
    });
  });
  group('SessionModel', () {
    test('fromJson and toJson should preserve properties including spaceSlug', () {
      final now = DateTime.now();
      final json = {
        'id': 'sess-123',
        'title': 'English Practice 1',
        'space_slug': 'english_c1',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final session = SessionModel.fromJson(json);
      expect(session.id, 'sess-123');
      expect(session.title, 'English Practice 1');
      expect(session.spaceSlug, 'english_c1');
      expect(session.toJson()['id'], 'sess-123');
      expect(session.toJson()['space_slug'], 'english_c1');
    });

    test('fromJson defaults null or missing space_slug to english_b2', () {
      final json = {
        'id': 'sess-456',
        'title': 'Default Session',
      };

      final session = SessionModel.fromJson(json);
      expect(session.spaceSlug, 'english_b2');
    });
  });

  group('ChatMessage', () {
    test('fromJson handles user and assistant messages properly', () {
      final jsonUser = {
        'id': 'msg-1',
        'session_id': 'sess-123',
        'role': 'user',
        'content': 'Hello Snape',
        'created_at': DateTime.now().toIso8601String(),
      };

      final userMsg = ChatMessage.fromJson(jsonUser);
      expect(userMsg.isUser, isTrue);
      expect(userMsg.isAssistant, isFalse);
      expect(userMsg.content, 'Hello Snape');

      final jsonAssistant = {
        'id': 'msg-2',
        'session_id': 'sess-123',
        'role': 'assistant',
        'content': 'Hello there! How are you doing today?',
        'created_at': DateTime.now().toIso8601String(),
      };

      final assistantMsg = ChatMessage.fromJson(jsonAssistant);
      expect(assistantMsg.isUser, isFalse);
      expect(assistantMsg.isAssistant, isTrue);
    });
  });

  group('WSOutputEvent Parsing', () {
    test('parses WSTokenEvent correctly', () {
      final json = {'type': 'token', 'content': 'Hello world'};
      final event = WSOutputEvent.fromJson(json);
      expect(event, isA<WSTokenEvent>());
      expect((event as WSTokenEvent).content, 'Hello world');
    });

    test('parses WSAudioEvent correctly', () {
      final json = {
        'type': 'audio',
        'sentence': 'How are you?',
        'audio_base64': 'UklGRg==',
        'format': 'wav',
        'sample_rate': 24000,
      };
      final event = WSOutputEvent.fromJson(json);
      expect(event, isA<WSAudioEvent>());
      final audio = event as WSAudioEvent;
      expect(audio.sentence, 'How are you?');
      expect(audio.audioBase64, 'UklGRg==');
    });

    test('parses WSDoneEvent correctly', () {
      final json = {
        'type': 'done',
        'session_id': 'sess-123',
        'user_message_id': 'user-1',
        'assistant_message_id': 'asst-1',
        'full_text': 'I am doing great!',
        'extracted_memories': ['User likes hiking'],
      };
      final event = WSOutputEvent.fromJson(json);
      expect(event, isA<WSDoneEvent>());
      final done = event as WSDoneEvent;
      expect(done.fullText, 'I am doing great!');
      expect(done.extractedMemories, ['User likes hiking']);
    });

    test('parses WSErrorEvent correctly', () {
      final json = {
        'type': 'error',
        'message': 'Session expired',
        'code': 'SESSION_EXPIRED',
      };
      final event = WSOutputEvent.fromJson(json);
      expect(event, isA<WSErrorEvent>());
      expect((event as WSErrorEvent).message, 'Session expired');
    });
  });

  group('TTS On-Demand Synthesis Data & Repo', () {
    test('ChatRemoteDataSource.synthesizeAudio returns audio bytes on 200', () async {
      final expectedBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/tts/synthesize'));
        expect(request.method, 'POST');
        final body = json.decode(request.body) as Map<String, dynamic>;
        expect(body['text'], 'Hello world');
        return http.Response.bytes(expectedBytes, 200);
      });

      final dataSource = ChatRemoteDataSource(client: mockClient, baseHttpUrl: 'https://test.api/api/v1');
      final result = await dataSource.synthesizeAudio('Hello world');
      expect(result, expectedBytes);
    });

    test('ChatRepositoryImpl.synthesizeAudio delegates to remote data source', () async {
      final expectedBytes = Uint8List.fromList([10, 20, 30]);
      final mockClient = MockClient((request) async {
        return http.Response.bytes(expectedBytes, 200);
      });

      final dataSource = ChatRemoteDataSource(client: mockClient, baseHttpUrl: 'https://test.api/api/v1');
      final repo = ChatRepositoryImpl(remoteDataSource: dataSource);
      final result = await repo.synthesizeAudio('Practice English');
      expect(result, expectedBytes);
    });
  });

  group('ChatRemoteDataSource Sessions with spaceSlug', () {
    test('getSessions passes space_slug query parameter if present', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/sessions'));
        expect(request.url.queryParameters['space_slug'], 'psychology');
        final responsePayload = [
          {
            'id': 'sess-100',
            'title': 'Mindfulness practice',
            'space_slug': 'psychology',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          }
        ];
        return http.Response(json.encode(responsePayload), 200);
      });

      final dataSource = ChatRemoteDataSource(client: mockClient, baseHttpUrl: 'https://test.api/api/v1');
      final sessions = await dataSource.getSessions(spaceSlug: 'psychology');
      expect(sessions.length, 1);
      expect(sessions.first.spaceSlug, 'psychology');
    });

    test('createSession includes space_slug in request body', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/sessions'));
        expect(request.method, 'POST');
        final body = json.decode(request.body) as Map<String, dynamic>;
        expect(body['title'], 'Deep Talk');
        expect(body['space_slug'], 'psychology');

        final responsePayload = {
          'id': 'sess-101',
          'title': 'Deep Talk',
          'space_slug': 'psychology',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };
        return http.Response(json.encode(responsePayload), 200);
      });

      final dataSource = ChatRemoteDataSource(client: mockClient, baseHttpUrl: 'https://test.api/api/v1');
      final session = await dataSource.createSession(title: 'Deep Talk', spaceSlug: 'psychology');
      expect(session.id, 'sess-101');
      expect(session.spaceSlug, 'psychology');
    });
  });

  group('SpaceRemoteDataSource & SpaceRepositoryImpl', () {
    test('getSpaces parses list of SpaceModel correctly on 200', () async {
      final spacesJson = [
        {
          'slug': 'english_b2',
          'display_name': 'English Chat (B2)',
          'cefr_level': 'B2',
          'voice_call_enabled': true,
          'tts_enabled': true,
        },
        {
          'slug': 'tech',
          'display_name': 'Technology & Architecture',
          'cefr_level': null,
          'voice_call_enabled': false,
          'tts_enabled': false,
        }
      ];

      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/spaces'));
        expect(request.method, 'GET');
        return http.Response(json.encode(spacesJson), 200);
      });

      final dataSource = SpaceRemoteDataSource(client: mockClient, baseHttpUrl: 'https://test.api/api/v1');
      final repo = SpaceRepositoryImpl(remoteDataSource: dataSource);

      final spaces = await repo.getSpaces();
      expect(spaces.length, 2);
      expect(spaces[0].slug, 'english_b2');
      expect(spaces[0].cefrLevel, 'B2');
      expect(spaces[1].slug, 'tech');
      expect(spaces[1].cefrLevel, isNull);
    });

    test('getSpaces throws Exception on failure', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final dataSource = SpaceRemoteDataSource(client: mockClient, baseHttpUrl: 'https://test.api/api/v1');
      expect(() => dataSource.getSpaces(), throwsA(isA<Exception>()));
    });
  });
}
