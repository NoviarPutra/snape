import 'package:flutter/foundation.dart';

sealed class WSOutputEvent {
  const WSOutputEvent();

  factory WSOutputEvent.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    switch (type) {
      case 'token':
        return WSTokenEvent(
          content: (json['content'] as String?) ?? '',
        );
      case 'audio':
        return WSAudioEvent(
          sentence: (json['sentence'] as String?) ?? '',
          audioBase64: (json['audio_base64'] as String?) ?? '',
          format: (json['format'] as String?) ?? 'wav',
          sampleRate: (json['sample_rate'] as int?) ?? 24000,
        );
      case 'done':
        return WSDoneEvent(
          sessionId: (json['session_id'] as String?) ?? '',
          userMessageId: json['user_message_id'] as String?,
          assistantMessageId: json['assistant_message_id'] as String?,
          fullText: (json['full_text'] as String?) ?? '',
          extractedMemories: (json['extracted_memories'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const [],
        );
      case 'pong':
        return const WSPongEvent();
      case 'error':
        return WSErrorEvent(
          message: (json['message'] as String?) ?? 'Unknown error',
          code: json['code'] as String?,
        );
      default:
        return WSUnknownEvent(type: type ?? 'unknown', raw: json);
    }
  }
}

@immutable
class WSTokenEvent extends WSOutputEvent {
  final String content;
  const WSTokenEvent({required this.content});
}

@immutable
class WSAudioEvent extends WSOutputEvent {
  final String sentence;
  final String audioBase64;
  final String format;
  final int sampleRate;

  const WSAudioEvent({
    required this.sentence,
    required this.audioBase64,
    this.format = 'wav',
    this.sampleRate = 24000,
  });
}

@immutable
class WSDoneEvent extends WSOutputEvent {
  final String sessionId;
  final String? userMessageId;
  final String? assistantMessageId;
  final String fullText;
  final List<String> extractedMemories;

  const WSDoneEvent({
    required this.sessionId,
    this.userMessageId,
    this.assistantMessageId,
    required this.fullText,
    this.extractedMemories = const [],
  });
}

@immutable
class WSPongEvent extends WSOutputEvent {
  const WSPongEvent();
}

@immutable
class WSErrorEvent extends WSOutputEvent {
  final String message;
  final String? code;

  const WSErrorEvent({
    required this.message,
    this.code,
  });
}

@immutable
class WSUnknownEvent extends WSOutputEvent {
  final String type;
  final Map<String, dynamic> raw;

  const WSUnknownEvent({
    required this.type,
    required this.raw,
  });
}
