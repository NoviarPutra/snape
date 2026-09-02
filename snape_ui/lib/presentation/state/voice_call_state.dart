import 'package:flutter/foundation.dart';

enum VoiceCallPhase {
  idle,
  greeting,
  listening,
  thinking,
  speaking,
}

@immutable
class VoiceCallState {
  final VoiceCallPhase phase;
  final String localeId;
  final bool isMuted;
  final bool showSubtitles;
  final String userSpeech;
  final String assistantSpeech;
  final String? errorMessage;

  const VoiceCallState({
    this.phase = VoiceCallPhase.idle,
    this.localeId = 'id_ID',
    this.isMuted = false,
    this.showSubtitles = true,
    this.userSpeech = '',
    this.assistantSpeech = '',
    this.errorMessage,
  });

  VoiceCallState copyWith({
    VoiceCallPhase? phase,
    String? localeId,
    bool? isMuted,
    bool? showSubtitles,
    String? userSpeech,
    String? assistantSpeech,
    String? errorMessage,
    bool clearError = false,
  }) {
    return VoiceCallState(
      phase: phase ?? this.phase,
      localeId: localeId ?? this.localeId,
      isMuted: isMuted ?? this.isMuted,
      showSubtitles: showSubtitles ?? this.showSubtitles,
      userSpeech: userSpeech ?? this.userSpeech,
      assistantSpeech: assistantSpeech ?? this.assistantSpeech,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceCallState &&
          runtimeType == other.runtimeType &&
          phase == other.phase &&
          localeId == other.localeId &&
          isMuted == other.isMuted &&
          showSubtitles == other.showSubtitles &&
          userSpeech == other.userSpeech &&
          assistantSpeech == other.assistantSpeech &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode =>
      phase.hashCode ^
      localeId.hashCode ^
      isMuted.hashCode ^
      showSubtitles.hashCode ^
      userSpeech.hashCode ^
      assistantSpeech.hashCode ^
      errorMessage.hashCode;
}
