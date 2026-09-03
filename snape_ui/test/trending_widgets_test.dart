import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snape_ui/core/theme/app_theme.dart';
import 'package:snape_ui/domain/models/trending_article.dart';
import 'package:snape_ui/presentation/widgets/trending_article_card.dart';
import 'package:snape_ui/presentation/widgets/trending_hero_banner.dart';

Widget wrapWithTheme(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (context, _) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleArticle = TrendingArticleModel(
    id: 'test-uuid-1',
    category: 'politics',
    title: 'Historic AI Treaty Signed in Geneva',
    summary:
        '- 45 countries sign the agreement.\n- Framework emphasizes ethical governance.\nWhy It\'s Trending: Unprecedented international consensus on AI regulations.',
    sourceUrl: 'https://example.com/ai-treaty',
    publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
    tags: const ['ai', 'treaty', 'geneva'],
    metadata: const {},
    createdAt: DateTime.now(),
  );

  group('TrendingHeroBanner', () {
    testWidgets('renders banner text and invokes onTap callback', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        wrapWithTheme(
          TrendingHeroBanner(onTap: () => tapped = true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('News & Trends Portal'), findsOneWidget);
      expect(find.text('REAL-TIME TRENDS'), findsOneWidget);
      expect(find.byIcon(Icons.newspaper_rounded), findsOneWidget);

      await tester.tap(find.byType(TrendingHeroBanner));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });
  });

  group('TrendingArticleCard', () {
    testWidgets('renders article details, bullets, rationale, and tags', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          TrendingArticleCard(article: sampleArticle),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('POLITICS'), findsOneWidget);
      expect(find.text('Historic AI Treaty Signed in Geneva'), findsOneWidget);
      expect(find.text('45 countries sign the agreement.'), findsOneWidget);
      expect(find.text('Framework emphasizes ethical governance.'), findsOneWidget);
      expect(find.textContaining('Unprecedented international consensus'), findsOneWidget);
      expect(find.text('#ai'), findsOneWidget);
      expect(find.text('Bahas (English)'), findsOneWidget);
      expect(find.text('Diskusi Santai'), findsOneWidget);
    });

    testWidgets('triggers discussion callbacks on button clicks', (tester) async {
      TrendingArticleModel? englishArticle;
      TrendingArticleModel? idArticle;

      await tester.pumpWidget(
        wrapWithTheme(
          TrendingArticleCard(
            article: sampleArticle,
            onEnglishDiscussion: (a) => englishArticle = a,
            onIndonesianDiscussion: (a) => idArticle = a,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bahas (English)'));
      await tester.pumpAndSettle();
      expect(englishArticle?.id, equals('test-uuid-1'));

      await tester.tap(find.text('Diskusi Santai'));
      await tester.pumpAndSettle();
      expect(idArticle?.id, equals('test-uuid-1'));
    });
  });
}
