import 'package:flutter/foundation.dart';

@immutable
class SessionModel {
  final String id;
  final String title;
  final String spaceSlug;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SessionModel({
    required this.id,
    required this.title,
    this.spaceSlug = 'english_b2',
    required this.createdAt,
    required this.updatedAt,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? 'New Practice Session',
      spaceSlug: (json['space_slug'] as String?) ??
          (json['spaceSlug'] as String?) ??
          'english_b2',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'space_slug': spaceSlug,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  SessionModel copyWith({
    String? id,
    String? title,
    String? spaceSlug,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SessionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      spaceSlug: spaceSlug ?? this.spaceSlug,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          spaceSlug == other.spaceSlug;

  @override
  int get hashCode => id.hashCode ^ title.hashCode ^ spaceSlug.hashCode;
}
