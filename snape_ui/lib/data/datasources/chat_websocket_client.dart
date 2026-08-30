import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/constants/api_constants.dart';
import '../models/websocket_events.dart';

typedef WebSocketFactory = WebSocketChannel Function(Uri uri);

class ChatWebSocketClient {
  final WebSocketFactory _channelFactory;
  final String _host;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  final _eventController = StreamController<WSOutputEvent>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();

  bool _isConnected = false;
  bool get isConnected => _isConnected;
  Stream<WSOutputEvent> get events => _eventController.stream;
  Stream<bool> get connectionState => _connectionStateController.stream;

  ChatWebSocketClient({
    WebSocketFactory? channelFactory,
    String? host,
  })  : _channelFactory = channelFactory ?? ((uri) => WebSocketChannel.connect(uri)),
        _host = host ?? ApiConstants.defaultHost;

  Future<void> connect(String sessionId) async {
    await disconnect();

    final uri = Uri.parse(ApiConstants.chatWsUrl(sessionId, host: _host));
    try {
      final channel = _channelFactory(uri);
      _channel = channel;

      _subscription = channel.stream.listen(
        (data) {
          if (!_isConnected) {
            _isConnected = true;
            _connectionStateController.add(true);
          }
          _handleIncomingData(data);
        },
        onDone: () {
          _isConnected = false;
          _connectionStateController.add(false);
        },
        onError: (error) {
          _isConnected = false;
          _connectionStateController.add(false);
          _eventController.add(WSErrorEvent(message: error.toString()));
        },
      );

      _isConnected = true;
      _connectionStateController.add(true);
    } catch (e) {
      _isConnected = false;
      _connectionStateController.add(false);
      _eventController.add(WSErrorEvent(message: 'Connection failed: $e'));
      rethrow;
    }
  }

  void _handleIncomingData(dynamic raw) {
    try {
      final Map<String, dynamic> jsonMap = raw is String
          ? json.decode(raw) as Map<String, dynamic>
          : json.decode(utf8.decode(raw as List<int>)) as Map<String, dynamic>;
      final event = WSOutputEvent.fromJson(jsonMap);
      _eventController.add(event);
    } catch (e) {
      _eventController.add(WSErrorEvent(message: 'Failed to decode message: $e'));
    }
  }

  void sendChat(String content) {
    if (_channel == null || !_isConnected) {
      throw StateError('Cannot send chat: WebSocket is not connected.');
    }
    final payload = json.encode({
      'type': 'chat',
      'content': content,
    });
    _channel!.sink.add(payload);
  }

  void sendPing() {
    if (_channel == null || !_isConnected) return;
    _channel!.sink.add(json.encode({'type': 'ping'}));
  }

  Future<void> disconnect() async {
    _isConnected = false;
    _connectionStateController.add(false);
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _eventController.close();
    _connectionStateController.close();
  }
}
