import 'package:flutter/foundation.dart';

enum MessageRole {
  user,
  assistant,
  system;

  static MessageRole fromString(String value) {
    switch (value.toLowerCase()) {
      case 'user':
        return MessageRole.user;
      case 'assistant':
        return MessageRole.assistant;
      case 'system':
        return MessageRole.system;
      default:
        return MessageRole.assistant;
    }
  }

  String toRoleString() {
    switch (this) {
      case MessageRole.user:
        return 'user';
      case MessageRole.assistant:
        return 'assistant';
      case MessageRole.system:
        return 'system';
    }
  }
}

enum MessageStatus {
  sending,
  streaming,
  delivered,
  error,
}

@immutable
class ChatMessage {
  final String id;
  final String sessionId;
  final MessageRole role;
  final String content;
  final String? audioPath;
  final Map<String, dynamic>? metaInfo;
  final List<String> extractedMemories;
  final DateTime createdAt;
  final bool isStreaming;
  final MessageStatus status;

  const ChatMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    this.audioPath,
    this.metaInfo,
    this.extractedMemories = const [],
    required this.createdAt,
    this.isStreaming = false,
    this.status = MessageStatus.delivered,
  });

  bool get isUser => role == MessageRole.user;
  bool get isAssistant => role == MessageRole.assistant;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    List<String> memories = const [];
    if (json['extracted_memories'] is List) {
      memories = (json['extracted_memories'] as List<dynamic>)
          .map((e) => e.toString())
          .toList();
    } else if (json['meta_info'] is Map &&
        json['meta_info']['extracted_memories'] is List) {
      memories = (json['meta_info']['extracted_memories'] as List<dynamic>)
          .map((e) => e.toString())
          .toList();
    }

    return ChatMessage(
      id: json['id'] as String,
      sessionId: (json['session_id'] as String?) ?? '',
      role: MessageRole.fromString((json['role'] as String?) ?? 'assistant'),
      content: (json['content'] as String?) ?? '',
      audioPath: json['audio_path'] as String?,
      metaInfo: json['meta_info'] as Map<String, dynamic>?,
      extractedMemories: memories,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      isStreaming: false,
      status: MessageStatus.delivered,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'role': role.toRoleString(),
      'content': content,
      'audio_path': audioPath,
      'meta_info': metaInfo,
      'extracted_memories': extractedMemories,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ChatMessage copyWith({
    String? id,
    String? sessionId,
    MessageRole? role,
    String? content,
    String? audioPath,
    Map<String, dynamic>? metaInfo,
    List<String>? extractedMemories,
    DateTime? createdAt,
    bool? isStreaming,
    MessageStatus? status,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      role: role ?? this.role,
      content: content ?? this.content,
      audioPath: audioPath ?? this.audioPath,
      metaInfo: metaInfo ?? this.metaInfo,
      extractedMemories: extractedMemories ?? this.extractedMemories,
      createdAt: createdAt ?? this.createdAt,
      isStreaming: isStreaming ?? this.isStreaming,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessage &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          content == other.content &&
          isStreaming == other.isStreaming &&
          status == other.status;

  @override
  int get hashCode =>
      id.hashCode ^ content.hashCode ^ isStreaming.hashCode ^ status.hashCode;
}
