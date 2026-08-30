import 'package:flutter/foundation.dart';

@immutable
class SessionModel {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SessionModel({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? 'New Practice Session',
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
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  SessionModel copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SessionModel(
      id: id ?? this.id,
      title: title ?? this.title,
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
          title == other.title;

  @override
  int get hashCode => id.hashCode ^ title.hashCode;
}
