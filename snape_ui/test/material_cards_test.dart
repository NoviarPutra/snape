import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snape_ui/core/theme/app_theme.dart';
import 'package:snape_ui/domain/models/material_parsed.dart';
import 'package:snape_ui/presentation/widgets/material_section_card.dart';
import 'package:snape_ui/presentation/widgets/material_vocab_card.dart';

Widget wrapWithTestApp(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (context, _) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  group('MaterialVocabCard Widget Tests', () {
    testWidgets('renders term, phonetic, part of speech, definition, and example', (tester) async {
      const item = VocabMaterialItem(
        id: 'v1',
        term: 'Good morning',
        phonetic: '/ɡʊd ˈmɔːnɪŋ/',
        partOfSpeech: 'phrase',
        definition: 'Polite greeting used before noon.',
        examples: ['Good morning, Paul. Welcome.'],
      );

      bool playTapped = false;

      await tester.pumpWidget(wrapWithTestApp(
        MaterialVocabCard(
          item: item,
          isPlaying: false,
          isLoadingAudio: false,
          onPlay: () => playTapped = true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Good morning'), findsOneWidget);
      expect(find.text('/ɡʊd ˈmɔːnɪŋ/'), findsOneWidget);
      expect(find.text('phrase'), findsOneWidget);
      expect(find.text('Polite greeting used before noon.'), findsOneWidget);
      expect(find.textContaining('Good morning, Paul. Welcome.'), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.volume_up_rounded));
      expect(playTapped, isTrue);
    });

    testWidgets('shows loading indicator when audio is synthesizing', (tester) async {
      const item = VocabMaterialItem(
        id: 'v1',
        term: 'Test Term',
        definition: 'Test Definition',
      );

      await tester.pumpWidget(wrapWithTestApp(
        MaterialVocabCard(
          item: item,
          isPlaying: false,
          isLoadingAudio: true,
          onPlay: () {},
        ),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows playing state icon when audio is currently playing', (tester) async {
      const item = VocabMaterialItem(
        id: 'v1',
        term: 'Test Term',
        definition: 'Test Definition',
      );

      await tester.pumpWidget(wrapWithTestApp(
        MaterialVocabCard(
          item: item,
          isPlaying: true,
          isLoadingAudio: false,
          onPlay: () {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.stop_circle_outlined), findsOneWidget);
    });
  });

  group('MaterialSectionCard Widget Tests', () {
    testWidgets('renders section title, content and triggers play callback', (tester) async {
      const item = SectionMaterialItem(
        id: 's1',
        title: 'Core Grammar Patterns',
        content: 'Structure: May I + verb?\nExplanation: Polite offer.',
        examples: ['May I help you?'],
      );

      bool playTapped = false;

      await tester.pumpWidget(wrapWithTestApp(
        MaterialSectionCard(
          item: item,
          isPlaying: false,
          isLoadingAudio: false,
          onPlay: () => playTapped = true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Core Grammar Patterns'), findsOneWidget);
      expect(find.textContaining('Structure: May I + verb?'), findsOneWidget);
      expect(find.textContaining('May I help you?'), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.volume_up_rounded));
      expect(playTapped, isTrue);
    });
  });
}
