import 'package:flutter/foundation.dart';

enum MaterialCategory {
  cheatsheet('cheatsheet', 'Cheatsheet'),
  vocabFormal('vocab-formal', 'Vocab Formal'),
  slang('slang', 'Slang');

  final String slug;
  final String label;

  const MaterialCategory(this.slug, this.label);

  static MaterialCategory fromSlug(String slug) {
    return MaterialCategory.values.firstWhere(
      (c) => c.slug == slug,
      orElse: () => MaterialCategory.cheatsheet,
    );
  }
}

@immutable
class MaterialItem {
  final String content;
  final String spaceSlug;
  final String category;

  const MaterialItem({
    required this.content,
    required this.spaceSlug,
    required this.category,
  });

  factory MaterialItem.fromJson(Map<String, dynamic> json) {
    return MaterialItem(
      content: (json['content'] as String?) ?? '',
      spaceSlug: (json['space_slug'] as String?) ?? '',
      category: (json['category'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'content': content,
        'space_slug': spaceSlug,
        'category': category,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaterialItem &&
          runtimeType == other.runtimeType &&
          content == other.content &&
          spaceSlug == other.spaceSlug &&
          category == other.category;

  @override
  int get hashCode =>
      content.hashCode ^ spaceSlug.hashCode ^ category.hashCode;
}
