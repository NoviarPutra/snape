import 'package:flutter/foundation.dart';
import '../../domain/models/chat_message.dart';

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

@immutable
class ChatState {
  final String? sessionId;
  final List<ChatMessage> messages;
  final bool isLoadingHistory;
  final bool isStreaming;
  final ConnectionStatus connectionStatus;
  final String? errorMessage;
  final String currentStreamingId;
  final List<String> lastExtractedMemories;
  final bool isSpeaking;
  final Map<String, List<Uint8List>> audioBuffers;
  final String? playingMessageId;
  final String? loadingAudioMessageId;

  const ChatState({
    this.sessionId,
    this.messages = const [],
    this.isLoadingHistory = false,
    this.isStreaming = false,
    this.connectionStatus = ConnectionStatus.disconnected,
    this.errorMessage,
    this.currentStreamingId = '',
    this.lastExtractedMemories = const [],
    this.isSpeaking = false,
    this.audioBuffers = const {},
    this.playingMessageId,
    this.loadingAudioMessageId,
  });

  bool get isConnected => connectionStatus == ConnectionStatus.connected;
  bool get isReconnecting => connectionStatus == ConnectionStatus.reconnecting;
  bool get isConnecting => connectionStatus == ConnectionStatus.connecting;
  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;

  ChatState copyWith({
    String? sessionId,
    List<ChatMessage>? messages,
    bool? isLoadingHistory,
    bool? isStreaming,
    ConnectionStatus? connectionStatus,
    String? errorMessage,
    String? currentStreamingId,
    List<String>? lastExtractedMemories,
    bool? isSpeaking,
    Map<String, List<Uint8List>>? audioBuffers,
    String? playingMessageId,
    String? loadingAudioMessageId,
    bool clearError = false,
    bool clearStreamingId = false,
    bool clearPlayingMessageId = false,
    bool clearLoadingAudioMessageId = false,
  }) {
    return ChatState(
      sessionId: sessionId ?? this.sessionId,
      messages: messages ?? this.messages,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      isStreaming: isStreaming ?? this.isStreaming,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      currentStreamingId: clearStreamingId
          ? ''
          : (currentStreamingId ?? this.currentStreamingId),
      lastExtractedMemories:
          lastExtractedMemories ?? this.lastExtractedMemories,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      audioBuffers: audioBuffers ?? this.audioBuffers,
      playingMessageId: clearPlayingMessageId
          ? null
          : (playingMessageId ?? this.playingMessageId),
      loadingAudioMessageId: clearLoadingAudioMessageId
          ? null
          : (loadingAudioMessageId ?? this.loadingAudioMessageId),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatState &&
          runtimeType == other.runtimeType &&
          sessionId == other.sessionId &&
          listEquals(messages, other.messages) &&
          isLoadingHistory == other.isLoadingHistory &&
          isStreaming == other.isStreaming &&
          connectionStatus == other.connectionStatus &&
          errorMessage == other.errorMessage &&
          currentStreamingId == other.currentStreamingId &&
          playingMessageId == other.playingMessageId &&
          loadingAudioMessageId == other.loadingAudioMessageId;

  @override
  int get hashCode =>
      sessionId.hashCode ^
      messages.hashCode ^
      isLoadingHistory.hashCode ^
      isStreaming.hashCode ^
      connectionStatus.hashCode ^
      errorMessage.hashCode ^
      currentStreamingId.hashCode ^
      playingMessageId.hashCode ^
      loadingAudioMessageId.hashCode;
}
