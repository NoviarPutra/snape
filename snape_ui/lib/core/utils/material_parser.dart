import '../../domain/models/material_item.dart';
import '../../domain/models/material_parsed.dart';

abstract final class MaterialParser {
  static List<ParsedMaterialItem> parse(
    String markdown, {
    MaterialCategory? category,
  }) {
    final cleaned = _stripFrontmatter(markdown).trim();
    if (cleaned.isEmpty) {
      return const [];
    }

    final lines = cleaned.split('\n');

    final isVocabOrSlang = category == MaterialCategory.vocabFormal ||
        category == MaterialCategory.slang ||
        _isPredominantlyBulletItems(lines);

    if (isVocabOrSlang && category != MaterialCategory.cheatsheet) {
      return _parseVocabAndSlang(lines);
    } else {
      return _parseSectionsAndCheatsheet(lines);
    }
  }

  static String _stripFrontmatter(String text) {
    if (!text.trimLeft().startsWith('---')) {
      return text;
    }
    final firstIndex = text.indexOf('---');
    final secondIndex = text.indexOf('---', firstIndex + 3);
    if (secondIndex != -1) {
      return text.substring(secondIndex + 3);
    }
    return text;
  }

  static bool _isPredominantlyBulletItems(List<String> lines) {
    int bulletCount = 0;
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        bulletCount++;
      }
    }
    return bulletCount >= 3;
  }

  static List<ParsedMaterialItem> _parseVocabAndSlang(List<String> lines) {
    final results = <ParsedMaterialItem>[];
    VocabMaterialItem? currentVocab;
    int itemIndex = 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        continue;
      }

      final isSubBullet = (line.startsWith('  ') || line.startsWith('\t')) &&
          (trimmed.startsWith('- ') || trimmed.startsWith('* '));

      if (isSubBullet && currentVocab != null) {
        String example = trimmed.substring(2).trim();
        example = example.replaceAll(RegExp(r'^\*+|\*+$'), '').trim();
        if (example.isNotEmpty) {
          final updatedExamples = [...currentVocab.examples, example];
          currentVocab = VocabMaterialItem(
            id: currentVocab.id,
            term: currentVocab.term,
            phonetic: currentVocab.phonetic,
            partOfSpeech: currentVocab.partOfSpeech,
            definition: currentVocab.definition,
            examples: updatedExamples,
          );
          results[results.length - 1] = currentVocab;
        }
        continue;
      }

      if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        final content = trimmed.substring(2).trim();
        final parsed = _parseSingleVocab(content, 'vocab_${itemIndex++}');
        if (parsed != null) {
          currentVocab = parsed;
          results.add(parsed);
        }
      }
    }

    if (results.isEmpty && lines.isNotEmpty) {
      return _parseSectionsAndCheatsheet(lines);
    }

    return results;
  }

  static VocabMaterialItem? _parseSingleVocab(String content, String id) {
    if (content.isEmpty) return null;

    String term = '';
    String rest = '';

    final boldMatch = RegExp(r'^\*\*([^*]+)\*\*\s*(.*)$').firstMatch(content);
    if (boldMatch != null) {
      term = boldMatch.group(1)!.trim();
      rest = boldMatch.group(2)!.trim();
    } else if (content.contains('—') || content.contains(' - ') || content.contains(': ')) {
      final parts = content.split(RegExp(r'\s+[—-]\s+|\s*:\s*'));
      term = parts.first.replaceAll(RegExp(r'[*_`]'), '').trim();
      rest = parts.sublist(1).join(' — ').trim();
    } else {
      term = content.replaceAll(RegExp(r'[*_`]'), '').trim();
      rest = '';
    }

    String? phonetic;
    final phoneticMatch = RegExp(r'(?:^|\s)\/([^\/]+)\/(?:\s|$)').firstMatch(rest);
    if (phoneticMatch != null) {
      phonetic = '/${phoneticMatch.group(1)!.trim()}/';
      rest = rest.replaceFirst(phoneticMatch.group(0)!, ' ').trim();
    }

    String? partOfSpeech;
    final posMatch = RegExp(r'(?:^|\s)\(([^)]+)\)(?:\s|$)').firstMatch(rest);
    if (posMatch != null) {
      partOfSpeech = posMatch.group(1)!.trim();
      rest = rest.replaceFirst(posMatch.group(0)!, ' ').trim();
    }

    rest = rest.replaceAll(RegExp(r'^[—\-:\s]+'), '').trim();
    rest = rest.replaceAll(RegExp(r'[*_`]'), '').trim();

    return VocabMaterialItem(
      id: id,
      term: term,
      phonetic: phonetic,
      partOfSpeech: partOfSpeech,
      definition: rest,
      examples: const [],
    );
  }

  static List<ParsedMaterialItem> _parseSectionsAndCheatsheet(List<String> lines) {
    final results = <ParsedMaterialItem>[];
    String currentTitle = '';
    final currentContentLines = <String>[];
    final currentExamples = <String>[];
    int sectionIndex = 0;

    void flushSection() {
      if (currentTitle.isNotEmpty || currentContentLines.isNotEmpty) {
        final contentStr = currentContentLines.join('\n').trim();
        results.add(SectionMaterialItem(
          id: 'sec_${sectionIndex++}',
          title: currentTitle.isEmpty ? 'Materi Ringkasan' : currentTitle,
          content: contentStr,
          examples: List.from(currentExamples),
        ));
        currentContentLines.clear();
        currentExamples.clear();
        currentTitle = '';
      }
    }

    for (final line in lines) {
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        if (currentContentLines.isNotEmpty && currentContentLines.last.isNotEmpty) {
          currentContentLines.add('');
        }
        continue;
      }

      if (trimmed.startsWith('#')) {
        final headingLevel = trimmed.indexOf(' ');
        final title = headingLevel != -1 ? trimmed.substring(headingLevel).trim() : trimmed;

        if (trimmed.startsWith('# ') && currentTitle.isEmpty && currentContentLines.isEmpty) {
          currentTitle = title;
          continue;
        }

        flushSection();
        currentTitle = title;
        continue;
      }

      if ((line.startsWith('  ') || line.startsWith('\t')) &&
          (trimmed.startsWith('- *') || trimmed.startsWith('* *') || trimmed.startsWith('- "'))) {
        String example = trimmed.substring(2).trim();
        example = example.replaceAll(RegExp(r'^\*+|\*+$'), '').trim();
        currentExamples.add(example);
        currentContentLines.add('  • $example');
        continue;
      }

      currentContentLines.add(line);
    }

    flushSection();
    return results;
  }
}
