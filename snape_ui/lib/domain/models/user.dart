import 'package:flutter/foundation.dart';

@immutable
class UserModel {
  final String id;
  final String username;
  final String? fullName;
  final String nativeLanguage;
  final String englishLevel;

  const UserModel({
    required this.id,
    required this.username,
    this.fullName,
    this.nativeLanguage = 'Indonesian',
    this.englishLevel = 'Intermediate',
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['id'] as String?) ?? '',
      username: (json['username'] as String?) ?? '',
      fullName: (json['full_name'] as String?) ?? (json['fullName'] as String?),
      nativeLanguage: (json['native_language'] as String?) ??
          (json['nativeLanguage'] as String?) ??
          'Indonesian',
      englishLevel: (json['english_level'] as String?) ??
          (json['englishLevel'] as String?) ??
          'Intermediate',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'native_language': nativeLanguage,
      'english_level': englishLevel,
    };
  }

  UserModel copyWith({
    String? id,
    String? username,
    String? fullName,
    String? nativeLanguage,
    String? englishLevel,
    bool clearFullName = false,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      fullName: clearFullName ? null : (fullName ?? this.fullName),
      nativeLanguage: nativeLanguage ?? this.nativeLanguage,
      englishLevel: englishLevel ?? this.englishLevel,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          username == other.username &&
          fullName == other.fullName &&
          nativeLanguage == other.nativeLanguage &&
          englishLevel == other.englishLevel;

  @override
  int get hashCode =>
      id.hashCode ^
      username.hashCode ^
      fullName.hashCode ^
      nativeLanguage.hashCode ^
      englishLevel.hashCode;
}
