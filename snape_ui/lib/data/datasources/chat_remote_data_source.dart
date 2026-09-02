import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';
import '../../core/constants/api_constants.dart';
import '../../domain/models/chat_message.dart';
import '../../domain/models/session.dart';

class ChatRemoteDataSource {
  final http.Client _client;
  final String _baseHttpUrl;

  ChatRemoteDataSource({
    http.Client? client,
    String? baseHttpUrl,
  })  : _client = client ?? http.Client(),
        _baseHttpUrl = baseHttpUrl ?? ApiConstants.baseHttpUrl;

  Future<List<SessionModel>> getSessions({int limit = 50, int offset = 0}) async {
    final uri = Uri.parse('$_baseHttpUrl/sessions?limit=$limit&offset=$offset');
    final response = await _client.get(uri, headers: AppConfig.defaultHeaders);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final List<dynamic> list = json.decode(response.body) as List<dynamic>;
      return list
          .map((item) => SessionModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Failed to load sessions: ${response.statusCode} ${response.body}');
    }
  }

  Future<SessionModel> createSession({String title = 'Casual English Chat'}) async {
    final uri = Uri.parse('$_baseHttpUrl/sessions');
    final response = await _client.post(
      uri,
      headers: AppConfig.defaultHeaders,
      body: json.encode({'title': title}),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final Map<String, dynamic> data = json.decode(response.body) as Map<String, dynamic>;
      return SessionModel.fromJson(data);
    } else {
      throw Exception('Failed to create session: ${response.statusCode} ${response.body}');
    }
  }

  Future<List<ChatMessage>> getSessionMessages(String sessionId) async {
    final uri = Uri.parse('$_baseHttpUrl/sessions/$sessionId');
    final response = await _client.get(uri, headers: AppConfig.defaultHeaders);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final Map<String, dynamic> data = json.decode(response.body) as Map<String, dynamic>;
      final List<dynamic> messagesList = (data['messages'] as List<dynamic>?) ?? [];
      return messagesList
          .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Failed to load session detail: ${response.statusCode} ${response.body}');
    }
  }

  Future<void> deleteSession(String sessionId) async {
    final uri = Uri.parse('$_baseHttpUrl/sessions/$sessionId');
    final response = await _client.delete(uri, headers: AppConfig.defaultHeaders);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to delete session: ${response.statusCode}');
    }
  }

  Future<Uint8List> synthesizeAudio(String text) async {
    final uri = Uri.parse('$_baseHttpUrl/tts/synthesize');
    final response = await _client.post(
      uri,
      headers: AppConfig.defaultHeaders,
      body: json.encode({'text': text}),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    } else {
      throw Exception('Failed to synthesize audio: ${response.statusCode} ${response.body}');
    }
  }
}
