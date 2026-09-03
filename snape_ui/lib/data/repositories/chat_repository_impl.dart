import 'dart:typed_data';

import '../../domain/models/chat_message.dart';
import '../../domain/models/session.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_remote_data_source.dart';
import '../datasources/chat_websocket_client.dart';
import '../models/websocket_events.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource _remoteDataSource;
  final ChatWebSocketClient _wsClient;

  ChatRepositoryImpl({
    ChatRemoteDataSource? remoteDataSource,
    ChatWebSocketClient? wsClient,
  })  : _remoteDataSource = remoteDataSource ?? ChatRemoteDataSource(),
        _wsClient = wsClient ?? ChatWebSocketClient();

  @override
  Future<List<SessionModel>> getSessions({String? spaceSlug}) {
    return _remoteDataSource.getSessions(spaceSlug: spaceSlug);
  }

  @override
  Future<SessionModel> createSession({
    String title = 'Casual English Chat',
    String spaceSlug = 'english_b2',
  }) {
    return _remoteDataSource.createSession(title: title, spaceSlug: spaceSlug);
  }

  @override
  Future<List<ChatMessage>> getSessionHistory(String sessionId) {
    return _remoteDataSource.getSessionMessages(sessionId);
  }

  @override
  Future<void> deleteSession(String sessionId) {
    return _remoteDataSource.deleteSession(sessionId);
  }

  @override
  Future<Uint8List> synthesizeAudio(String text) {
    return _remoteDataSource.synthesizeAudio(text);
  }

  @override
  Future<void> connectToChatStream(String sessionId) {
    return _wsClient.connect(sessionId);
  }

  @override
  void sendChatMessage(String content) {
    _wsClient.sendChat(content);
  }

  @override
  Stream<WSOutputEvent> get chatEvents => _wsClient.events;

  @override
  Stream<bool> get connectionStatus => _wsClient.connectionState;

  @override
  bool get isConnected => _wsClient.isConnected;

  @override
  Future<void> disconnectStream() {
    return _wsClient.disconnect();
  }

  @override
  void dispose() {
    _wsClient.dispose();
  }
}
