import 'package:flutter_test/flutter_test.dart';
import 'package:snape_ui/core/utils/material_parser.dart';
import 'package:snape_ui/domain/models/material_item.dart';
import 'package:snape_ui/domain/models/material_parsed.dart';

void main() {
  group('MaterialParser Tests', () {
    test('strips frontmatter YAML cleanly', () {
      const markdown = '''---
Title: "vocab-formal"
Level: "A1"
Tags:
  - snape-material
---
# vocab-formal
- **Good morning** /ɡʊd ˈmɔːnɪŋ/ (phrase) — Polite greeting used before 12:00 PM.
  - *Good morning, Mr. Smith. Welcome back.*
''';

      final items = MaterialParser.parse(markdown, category: MaterialCategory.vocabFormal);
      expect(items.isNotEmpty, isTrue);
      final vocabItem = items.whereType<VocabMaterialItem>().first;
      expect(vocabItem.term, 'Good morning');
      expect(vocabItem.phonetic, '/ɡʊd ˈmɔːnɪŋ/');
      expect(vocabItem.partOfSpeech, 'phrase');
      expect(vocabItem.definition, 'Polite greeting used before 12:00 PM.');
      expect(vocabItem.examples, contains('Good morning, Mr. Smith. Welcome back.'));
      expect(vocabItem.speakableText, 'Good morning. Polite greeting used before 12:00 PM.');
    });

    test('parses slang bullet with example sentence', () {
      const markdown = '''
# slang
- **hit the books** (idiom) — to study hard for exams.
  - *I need to hit the books tonight for my test.*
- **couch potato** (noun) — a lazy person who watches a lot of TV.
  - *Don't be a couch potato all weekend.*
''';

      final items = MaterialParser.parse(markdown, category: MaterialCategory.slang);
      final vocabItems = items.whereType<VocabMaterialItem>().toList();
      expect(vocabItems.length, 2);
      expect(vocabItems[0].term, 'hit the books');
      expect(vocabItems[0].partOfSpeech, 'idiom');
      expect(vocabItems[0].definition, 'to study hard for exams.');
      expect(vocabItems[0].examples.first, 'I need to hit the books tonight for my test.');

      expect(vocabItems[1].term, 'couch potato');
      expect(vocabItems[1].partOfSpeech, 'noun');
      expect(vocabItems[1].definition, 'a lazy person who watches a lot of TV.');
    });

    test('parses simple bullet without phonetic or part of speech', () {
      const markdown = '''
- Furthermore — in addition to what has been said
- Moreover
''';

      final items = MaterialParser.parse(markdown, category: MaterialCategory.vocabFormal);
      final vocabItems = items.whereType<VocabMaterialItem>().toList();
      expect(vocabItems.length, 2);
      expect(vocabItems[0].term, 'Furthermore');
      expect(vocabItems[0].definition, 'in addition to what has been said');
      expect(vocabItems[1].term, 'Moreover');
    });

    test('parses cheatsheet sections with patterns and dialogue', () {
      const markdown = '''
## 1. Core Grammar Patterns
### Pattern 1: Offering Help
- **Structure:** `May I + verb?`
- **Explanation:** Use "May I" to offer assistance.
- **Examples:**
  - *May I help you?*
  - *May I take your coat?*

## 2. Practical Dialogue
**Receptionist:** Good morning, Sir.
**Guest:** Good morning, I have a reservation.
''';

      final items = MaterialParser.parse(markdown, category: MaterialCategory.cheatsheet);
      expect(items.isNotEmpty, isTrue);

      final sections = items.whereType<SectionMaterialItem>().toList();
      expect(sections.length, greaterThanOrEqualTo(2));
      expect(sections[0].title, contains('Core Grammar Patterns'));
      expect(sections.any((s) => s.title.contains('Dialogue')), isTrue);
    });

    test('handles empty and malformed markdown gracefully without throwing', () {
      expect(MaterialParser.parse(''), isEmpty);
      expect(MaterialParser.parse('   \n\n  '), isEmpty);

      final raw = MaterialParser.parse('Random plain text without formatting');
      expect(raw.isNotEmpty, isTrue);
    });
  });
}
