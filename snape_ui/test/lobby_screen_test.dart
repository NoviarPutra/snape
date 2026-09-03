import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snape_ui/core/theme/app_theme.dart';
import 'package:snape_ui/domain/models/space.dart';
import 'package:snape_ui/domain/repositories/space_repository.dart';
import 'package:snape_ui/presentation/screens/level_picker_screen.dart';
import 'package:snape_ui/presentation/screens/lobby_screen.dart';
import 'package:snape_ui/presentation/screens/session_list_screen.dart';
import 'package:snape_ui/presentation/state/providers.dart';

class MockSpaceRepository implements SpaceRepository {
  List<SpaceModel> spaces = [];
  bool shouldThrow = false;

  @override
  Future<List<SpaceModel>> getSpaces() async {
    if (shouldThrow) {
      throw Exception('Network error');
    }
    return spaces;
  }
}

Widget createLobbyTestApp({required MockSpaceRepository repository}) {
  return ProviderScope(
    overrides: [
      spaceRepositoryProvider.overrideWithValue(repository),
    ],
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, child) => MaterialApp(
        theme: AppTheme.lightTheme,
        home: const LobbyScreen(),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleSpaces = [
    const SpaceModel(
      slug: 'english_b2',
      displayName: 'B2 – Conversational',
      cefrLevel: 'b2',
      voiceCallEnabled: true,
      ttsEnabled: true,
    ),
    const SpaceModel(
      slug: 'tech',
      displayName: 'Teknologi',
      cefrLevel: null,
      voiceCallEnabled: false,
      ttsEnabled: false,
    ),
    const SpaceModel(
      slug: 'psychology',
      displayName: 'Psikologi',
      cefrLevel: null,
      voiceCallEnabled: false,
      ttsEnabled: false,
    ),
    const SpaceModel(
      slug: 'productivity',
      displayName: 'Produktivitas',
      cefrLevel: null,
      voiceCallEnabled: false,
      ttsEnabled: false,
    ),
  ];

  testWidgets('LobbyScreen displays featured English card and non-English grid',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final repo = MockSpaceRepository()..spaces = sampleSpaces;
    await tester.pumpWidget(createLobbyTestApp(repository: repo));
    await tester.pumpAndSettle();

    expect(find.text('English Learning Companion'), findsOneWidget);
    expect(find.text('Teknologi'), findsOneWidget);
    expect(find.text('Psikologi'), findsOneWidget);
    expect(find.text('Produktivitas'), findsOneWidget);
  });

  testWidgets('LobbyScreen displays error view with retry button on failure',
      (tester) async {
    final repo = MockSpaceRepository()..shouldThrow = true;
    await tester.pumpWidget(createLobbyTestApp(repository: repo));
    await tester.pumpAndSettle();

    expect(find.text('Unable to Load Spaces'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);

    repo.shouldThrow = false;
    repo.spaces = sampleSpaces;
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();

    expect(find.text('English Learning Companion'), findsOneWidget);
  });

  testWidgets(
      'Tapping English Learning card navigates to LevelPickerScreen',
      (tester) async {
    final repo = MockSpaceRepository()..spaces = sampleSpaces;
    await tester.pumpWidget(createLobbyTestApp(repository: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('English Learning Companion'));
    await tester.pumpAndSettle();

    expect(find.byType(LevelPickerScreen), findsOneWidget);
  });

  testWidgets(
      'Tapping a non-English space card navigates to SessionListScreen',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final repo = MockSpaceRepository()..spaces = sampleSpaces;
    await tester.pumpWidget(createLobbyTestApp(repository: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Teknologi'));
    await tester.pumpAndSettle();

    expect(find.byType(SessionListScreen), findsOneWidget);
    expect(find.text('Teknologi'), findsWidgets);
  });
}
