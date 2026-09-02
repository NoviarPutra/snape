import 'dart:typed_data';

import '../../data/models/websocket_events.dart';
import '../models/chat_message.dart';
import '../models/session.dart';

abstract class ChatRepository {
  Future<List<SessionModel>> getSessions();
  Future<SessionModel> createSession({String title});
  Future<List<ChatMessage>> getSessionHistory(String sessionId);
  Future<void> deleteSession(String sessionId);
  Future<Uint8List> synthesizeAudio(String text);

  Future<void> connectToChatStream(String sessionId);
  void sendChatMessage(String content);
  Stream<WSOutputEvent> get chatEvents;
  Stream<bool> get connectionStatus;
  bool get isConnected;
  Future<void> disconnectStream();
  void dispose();
}
