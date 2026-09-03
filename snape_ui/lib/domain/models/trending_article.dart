import 'package:flutter/foundation.dart';

@immutable
class TrendingArticleModel {
  final String id;
  final String category;
  final String title;
  final String summary;
  final String sourceUrl;
  final DateTime publishedAt;
  final List<String> tags;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const TrendingArticleModel({
    required this.id,
    required this.category,
    required this.title,
    required this.summary,
    required this.sourceUrl,
    required this.publishedAt,
    this.tags = const [],
    this.metadata = const {},
    required this.createdAt,
  });

  factory TrendingArticleModel.fromJson(Map<String, dynamic> json) {
    return TrendingArticleModel(
      id: json['id'] as String,
      category: (json['category'] as String?) ?? 'general',
      title: (json['title'] as String?) ?? '',
      summary: (json['summary'] as String?) ?? '',
      sourceUrl: (json['source_url'] as String?) ??
          (json['sourceUrl'] as String?) ??
          '',
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'] as String)
          : (json['publishedAt'] != null
              ? DateTime.parse(json['publishedAt'] as String)
              : DateTime.now()),
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      metadata: (json['metadata'] as Map<String, dynamic>?) ??
          (json['metadata_'] as Map<String, dynamic>?) ??
          const {},
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : (json['createdAt'] != null
              ? DateTime.parse(json['createdAt'] as String)
              : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'title': title,
      'summary': summary,
      'source_url': sourceUrl,
      'published_at': publishedAt.toIso8601String(),
      'tags': tags,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
    };
  }

  TrendingArticleModel copyWith({
    String? id,
    String? category,
    String? title,
    String? summary,
    String? sourceUrl,
    DateTime? publishedAt,
    List<String>? tags,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) {
    return TrendingArticleModel(
      id: id ?? this.id,
      category: category ?? this.category,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      publishedAt: publishedAt ?? this.publishedAt,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get categoryDisplayName {
    switch (category.toLowerCase()) {
      case 'politics':
        return 'Politics';
      case 'general':
        return 'General News';
      case 'music':
        return 'Music';
      case 'creator_trends':
        return 'Creator Trends';
      default:
        return category;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrendingArticleModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          category == other.category &&
          title == other.title &&
          summary == other.summary &&
          sourceUrl == other.sourceUrl &&
          publishedAt == other.publishedAt &&
          listEquals(tags, other.tags) &&
          mapEquals(metadata, other.metadata) &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^
      category.hashCode ^
      title.hashCode ^
      summary.hashCode ^
      sourceUrl.hashCode ^
      publishedAt.hashCode ^
      tags.hashCode ^
      metadata.hashCode ^
      createdAt.hashCode;
}
