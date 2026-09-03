import 'package:flutter/foundation.dart';

@immutable
abstract class ParsedMaterialItem {
  final String id;
  const ParsedMaterialItem({required this.id});

  String get speakableText;
}

@immutable
class VocabMaterialItem extends ParsedMaterialItem {
  final String term;
  final String? phonetic;
  final String? partOfSpeech;
  final String definition;
  final List<String> examples;

  const VocabMaterialItem({
    required super.id,
    required this.term,
    this.phonetic,
    this.partOfSpeech,
    required this.definition,
    this.examples = const [],
  });

  @override
  String get speakableText {
    final cleanTerm = term.replaceAll(RegExp(r'[*_`]'), '').trim();
    final cleanDef = definition.replaceAll(RegExp(r'[*_`]'), '').trim();
    if (cleanDef.isNotEmpty) {
      return '$cleanTerm. $cleanDef';
    }
    return cleanTerm;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VocabMaterialItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          term == other.term &&
          phonetic == other.phonetic &&
          partOfSpeech == other.partOfSpeech &&
          definition == other.definition &&
          listEquals(examples, other.examples);

  @override
  int get hashCode =>
      id.hashCode ^
      term.hashCode ^
      phonetic.hashCode ^
      partOfSpeech.hashCode ^
      definition.hashCode ^
      examples.hashCode;
}

@immutable
class SectionMaterialItem extends ParsedMaterialItem {
  final String title;
  final String? subtitle;
  final String content;
  final List<String> examples;
  final List<VocabMaterialItem> items;

  const SectionMaterialItem({
    required super.id,
    required this.title,
    this.subtitle,
    this.content = '',
    this.examples = const [],
    this.items = const [],
  });

  @override
  String get speakableText {
    final buffer = StringBuffer();
    if (title.isNotEmpty) {
      final cleanTitle = title.replaceAll(RegExp(r'[#*_`]'), '').trim();
      buffer.writeln(cleanTitle);
    }
    if (content.isNotEmpty) {
      final cleanContent = content.replaceAll(RegExp(r'[#*_`]'), '').trim();
      buffer.writeln(cleanContent);
    }
    for (final ex in examples) {
      final cleanEx = ex.replaceAll(RegExp(r'[*_`]'), '').trim();
      buffer.writeln(cleanEx);
    }
    return buffer.toString().trim();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SectionMaterialItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          subtitle == other.subtitle &&
          content == other.content &&
          listEquals(examples, other.examples) &&
          listEquals(items, other.items);

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      subtitle.hashCode ^
      content.hashCode ^
      examples.hashCode ^
      items.hashCode;
}
