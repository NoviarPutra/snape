import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snape_ui/core/theme/app_theme.dart';
import 'package:snape_ui/domain/repositories/material_repository.dart';
import 'package:snape_ui/presentation/state/providers.dart';
import 'package:snape_ui/presentation/widgets/materials_panel.dart';

class MockMaterialRepository implements MaterialRepository {
  final Map<String, String?> materials = {};
  bool shouldThrow = false;
  Duration delay = Duration.zero;

  @override
  Future<String?> getMaterial(String spaceSlug, String category) async {
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }
    if (shouldThrow) {
      throw Exception('Connection failed');
    }
    return materials['$spaceSlug/$category'];
  }
}

Widget createMaterialsTestApp({
  required MockMaterialRepository repository,
  String spaceSlug = 'english_b2',
  String? cefrLevel = 'B2',
  String? displayName = 'English Chat (B2)',
}) {
  return ProviderScope(
    overrides: [
      materialRepositoryProvider.overrideWithValue(repository),
    ],
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, child) => MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: MaterialsPanel(
            spaceSlug: spaceSlug,
            cefrLevel: cefrLevel,
            displayName: displayName,
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MaterialsPanel Widget Tests', () {
    late MockMaterialRepository repository;

    setUp(() {
      repository = MockMaterialRepository();
      repository.materials['english_b2/cheatsheet'] = '# B2 Grammar Cheatsheet\n- Present Perfect Continuous';
      repository.materials['english_b2/vocab-formal'] = '# B2 Formal Vocab\n- Furthermore\n- Moreover';
    });

    testWidgets('renders category tabs Cheatsheet, Vocab Formal, Slang', (tester) async {
      await tester.pumpWidget(createMaterialsTestApp(repository: repository));
      await tester.pumpAndSettle();

      expect(find.text('Cheatsheet'), findsOneWidget);
      expect(find.text('Vocab Formal'), findsOneWidget);
      expect(find.text('Slang'), findsOneWidget);
    });

    testWidgets('shows loading state while fetching material', (tester) async {
      repository.delay = const Duration(milliseconds: 300);
      await tester.pumpWidget(createMaterialsTestApp(repository: repository));
      // Pump initial frame before async resolution
      await tester.pump();

      // Should be loading (AnimatedBuilder in _buildShimmerLoading)
      expect(find.byType(AnimatedBuilder), findsWidgets);

      // Settle the delayed response
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.textContaining('Present Perfect Continuous'), findsOneWidget);
    });

    testWidgets('displays content when material is loaded successfully', (tester) async {
      await tester.pumpWidget(createMaterialsTestApp(repository: repository));
      await tester.pumpAndSettle();

      expect(find.textContaining('Present Perfect Continuous'), findsOneWidget);
    });

    testWidgets('switches tab and loads category content lazily', (tester) async {
      await tester.pumpWidget(createMaterialsTestApp(repository: repository));
      await tester.pumpAndSettle();

      expect(find.textContaining('Present Perfect Continuous'), findsOneWidget);

      // Tap 'Vocab Formal'
      await tester.tap(find.text('Vocab Formal'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Furthermore'), findsOneWidget);
    });

    testWidgets('displays empty state message on 404 null content', (tester) async {
      await tester.pumpWidget(createMaterialsTestApp(repository: repository));
      await tester.pumpAndSettle();

      // Slang is not in repository.materials -> returns null (404)
      await tester.tap(find.text('Slang'));
      await tester.pumpAndSettle();

      expect(find.text('Materi untuk level ini belum tersedia'), findsOneWidget);
    });

    testWidgets('displays error state and retries on failure', (tester) async {
      repository.shouldThrow = true;

      await tester.pumpWidget(createMaterialsTestApp(repository: repository));
      await tester.pumpAndSettle();

      expect(find.textContaining('Connection failed'), findsOneWidget);
      expect(find.text('Coba Lagi'), findsOneWidget);

      // Fix error and retry
      repository.shouldThrow = false;
      await tester.tap(find.text('Coba Lagi'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Present Perfect Continuous'), findsOneWidget);
    });
  });
}
