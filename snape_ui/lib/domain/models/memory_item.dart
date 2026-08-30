import 'package:flutter/foundation.dart';

@immutable
class MemoryItem {
  final String id;
  final String userId;
  final String category;
  final String content;
  final DateTime createdAt;

  const MemoryItem({
    required this.id,
    required this.userId,
    required this.category,
    required this.content,
    required this.createdAt,
  });

  factory MemoryItem.fromJson(Map<String, dynamic> json) {
    return MemoryItem(
      id: json['id'] as String,
      userId: (json['user_id'] as String?) ?? '',
      category: (json['category'] as String?) ?? 'fact',
      content: (json['content'] as String?) ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'category': category,
      'content': content,
      'created_at': createdAt.toIso8601String(),
    };
  }

  MemoryItem copyWith({
    String? id,
    String? userId,
    String? category,
    String? content,
    DateTime? createdAt,
  }) {
    return MemoryItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      category: category ?? this.category,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemoryItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          category == other.category &&
          content == other.content &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^
      userId.hashCode ^
      category.hashCode ^
      content.hashCode ^
      createdAt.hashCode;
}
