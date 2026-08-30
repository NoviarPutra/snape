import 'package:flutter_test/flutter_test.dart';
import 'package:snape_ui/data/models/websocket_events.dart';
import 'package:snape_ui/domain/models/chat_message.dart';
import 'package:snape_ui/domain/models/memory_item.dart';
import 'package:snape_ui/domain/models/session.dart';

void main() {
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
    test('fromJson and toJson should preserve properties', () {
      final now = DateTime.now();
      final json = {
        'id': 'sess-123',
        'title': 'English Practice 1',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final session = SessionModel.fromJson(json);
      expect(session.id, 'sess-123');
      expect(session.title, 'English Practice 1');
      expect(session.toJson()['id'], 'sess-123');
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
}
