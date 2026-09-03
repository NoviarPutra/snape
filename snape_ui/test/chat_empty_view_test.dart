import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snape_ui/core/theme/app_theme.dart';
import 'package:snape_ui/domain/models/space.dart';
import 'package:snape_ui/presentation/widgets/chat_empty_view.dart';

Widget createEmptyViewTestApp({
  List<String>? starterPrompts,
  SpaceModel? space,
  ValueChanged<String>? onSelectPrompt,
  VoidCallback? onStartPrompt,
}) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (context, child) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: ChatEmptyView(
          starterPrompts: starterPrompts,
          space: space,
          onSelectPrompt: onSelectPrompt,
          onStartPrompt: onStartPrompt,
        ),
      ),
    ),
  );
}

void main() {
  group('ChatEmptyView', () {
    testWidgets('renders default prompts when no starter prompts or space provided',
        (tester) async {
      await tester.pumpWidget(createEmptyViewTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Your English Companion'), findsOneWidget);
      expect(find.text('Hey Snape, how was your day?'), findsOneWidget);
      expect(
        find.text('Bisa bantu latihan speaking buat interview?'),
        findsOneWidget,
      );
    });

    testWidgets('renders dynamic starter prompts when starterPrompts list provided',
        (tester) async {
      final prompts = [
        'How do socioeconomic factors influence urban development?',
        'Let\'s explore the ethical implications of artificial intelligence.',
        'What are the nuances between assertive and aggressive communication?',
      ];

      await tester.pumpWidget(createEmptyViewTestApp(
        starterPrompts: prompts,
      ));
      await tester.pumpAndSettle();

      for (final p in prompts) {
        expect(find.text(p), findsOneWidget);
      }
      expect(find.text('Hey Snape, how was your day?'), findsNothing);
    });

    testWidgets('renders starter prompts from space model when space is provided',
        (tester) async {
      const space = SpaceModel(
        slug: 'tech',
        displayName: 'Teknologi',
        cefrLevel: null,
        voiceCallEnabled: false,
        ttsEnabled: false,
        starterPrompts: [
          'Apa perbedaan utama arsitektur monolitik dan microservices?',
          'Bagaimana cara memilih database SQL vs NoSQL untuk aplikasi baru?',
          'Tren teknologi apa yang paling menarik perhatianmu saat ini?',
        ],
      );

      await tester.pumpWidget(createEmptyViewTestApp(
        space: space,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Teknologi'), findsOneWidget);
      expect(
        find.text('Apa perbedaan utama arsitektur monolitik dan microservices?'),
        findsOneWidget,
      );
      expect(
        find.text('Bagaimana cara memilih database SQL vs NoSQL untuk aplikasi baru?'),
        findsOneWidget,
      );
      expect(
        find.text('Tren teknologi apa yang paling menarik perhatianmu saat ini?'),
        findsOneWidget,
      );
    });

    testWidgets('tapping a starter prompt triggers onSelectPrompt with the selected prompt',
        (tester) async {
      String? selectedPrompt;
      final prompts = [
        'Prompt 1: Let\'s talk about weather.',
        'Prompt 2: Tell me a story.',
        'Prompt 3: Quiz me on vocab.',
      ];

      await tester.pumpWidget(createEmptyViewTestApp(
        starterPrompts: prompts,
        onSelectPrompt: (prompt) {
          selectedPrompt = prompt;
        },
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Prompt 2: Tell me a story.'));
      await tester.pumpAndSettle();

      expect(selectedPrompt, 'Prompt 2: Tell me a story.');
    });
  });
}
