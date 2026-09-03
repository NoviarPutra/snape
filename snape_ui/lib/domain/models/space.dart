import 'package:flutter/foundation.dart';

@immutable
class SpaceModel {
  final String slug;
  final String displayName;
  final String? cefrLevel;
  final bool voiceCallEnabled;
  final bool ttsEnabled;
  final List<String> starterPrompts;

  const SpaceModel({
    required this.slug,
    required this.displayName,
    this.cefrLevel,
    required this.voiceCallEnabled,
    required this.ttsEnabled,
    this.starterPrompts = const [],
  });

  factory SpaceModel.fromJson(Map<String, dynamic> json) {
    return SpaceModel(
      slug: json['slug'] as String,
      displayName: (json['display_name'] as String?) ??
          (json['displayName'] as String?) ??
          '',
      cefrLevel: (json['cefr_level'] as String?) ??
          (json['cefrLevel'] as String?),
      voiceCallEnabled: (json['voice_call_enabled'] as bool?) ??
          (json['voiceCallEnabled'] as bool?) ??
          false,
      ttsEnabled: (json['tts_enabled'] as bool?) ??
          (json['ttsEnabled'] as bool?) ??
          false,
      starterPrompts: (json['starter_prompts'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          (json['starterPrompts'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'slug': slug,
      'display_name': displayName,
      'cefr_level': cefrLevel,
      'voice_call_enabled': voiceCallEnabled,
      'tts_enabled': ttsEnabled,
      'starter_prompts': starterPrompts,
    };
  }

  SpaceModel copyWith({
    String? slug,
    String? displayName,
    String? cefrLevel,
    bool? voiceCallEnabled,
    bool? ttsEnabled,
    List<String>? starterPrompts,
    bool clearCefrLevel = false,
  }) {
    return SpaceModel(
      slug: slug ?? this.slug,
      displayName: displayName ?? this.displayName,
      cefrLevel: clearCefrLevel ? null : (cefrLevel ?? this.cefrLevel),
      voiceCallEnabled: voiceCallEnabled ?? this.voiceCallEnabled,
      ttsEnabled: ttsEnabled ?? this.ttsEnabled,
      starterPrompts: starterPrompts ?? this.starterPrompts,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpaceModel &&
          runtimeType == other.runtimeType &&
          slug == other.slug &&
          displayName == other.displayName &&
          cefrLevel == other.cefrLevel &&
          voiceCallEnabled == other.voiceCallEnabled &&
          ttsEnabled == other.ttsEnabled &&
          listEquals(starterPrompts, other.starterPrompts);

  @override
  int get hashCode =>
      slug.hashCode ^
      displayName.hashCode ^
      cefrLevel.hashCode ^
      voiceCallEnabled.hashCode ^
      ttsEnabled.hashCode ^
      Object.hashAll(starterPrompts);

  @override
  String toString() =>
      'SpaceModel(slug: $slug, displayName: $displayName, cefrLevel: $cefrLevel, voiceCallEnabled: $voiceCallEnabled, ttsEnabled: $ttsEnabled, starterPrompts: $starterPrompts)';
}
