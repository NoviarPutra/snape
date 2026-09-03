import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snape_ui/core/theme/app_theme.dart';
import 'package:snape_ui/domain/models/space.dart';
import 'package:snape_ui/domain/models/user.dart';
import 'package:snape_ui/domain/repositories/space_repository.dart';
import 'package:snape_ui/domain/repositories/user_repository.dart';
import 'package:snape_ui/presentation/screens/level_picker_screen.dart';
import 'package:snape_ui/presentation/screens/session_list_screen.dart';
import 'package:snape_ui/presentation/state/providers.dart';

class MockUserRepository implements UserRepository {
  UserModel user = const UserModel(
    id: '1',
    username: 'learner',
    englishLevel: 'Intermediate',
  );

  @override
  Future<UserModel> getUserProfile() async => user;
}

class MockSpaceRepository implements SpaceRepository {
  List<SpaceModel> spaces = [];

  @override
  Future<List<SpaceModel>> getSpaces() async => spaces;
}

Widget createLevelPickerTestApp({
  required MockUserRepository userRepo,
  MockSpaceRepository? spaceRepo,
}) {
  return ProviderScope(
    overrides: [
      userRepositoryProvider.overrideWithValue(userRepo),
      if (spaceRepo != null)
        spaceRepositoryProvider.overrideWithValue(spaceRepo),
    ],
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, child) => MaterialApp(
        theme: AppTheme.lightTheme,
        home: const LevelPickerScreen(),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('LevelPickerScreen renders all 6 CEFR levels', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final userRepo = MockUserRepository();
    await tester.pumpWidget(createLevelPickerTestApp(userRepo: userRepo));
    await tester.pumpAndSettle();

    expect(find.text('A1 – Just Starting'), findsOneWidget);
    expect(find.text('A2 – Building Basics'), findsOneWidget);
    expect(find.text('B1 – Getting Comfortable'), findsOneWidget);
    expect(find.text('B2 – Conversational'), findsOneWidget);
    expect(find.text('C1 – Advanced'), findsOneWidget);
    expect(find.text('C2 – Mastery'), findsOneWidget);
  });

  testWidgets(
      'LevelPickerScreen highlights B2 as Recommended for Intermediate profile',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final userRepo = MockUserRepository()
      ..user = const UserModel(
        id: '1',
        username: 'learner',
        englishLevel: 'Intermediate',
      );

    await tester.pumpWidget(createLevelPickerTestApp(userRepo: userRepo));
    await tester.pumpAndSettle();

    expect(find.text('Recommended'), findsOneWidget);
  });

  testWidgets(
      'LevelPickerScreen highlights A1 as Recommended for Beginner profile',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final userRepo = MockUserRepository()
      ..user = const UserModel(
        id: '1',
        username: 'learner',
        englishLevel: 'Beginner',
      );

    await tester.pumpWidget(createLevelPickerTestApp(userRepo: userRepo));
    await tester.pumpAndSettle();

    expect(find.text('Recommended'), findsOneWidget);
  });

  testWidgets(
      'Tapping a CEFR level selects the space and navigates to SessionListScreen',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final userRepo = MockUserRepository();
    final spaceRepo = MockSpaceRepository()
      ..spaces = [
        const SpaceModel(
          slug: 'english_b2',
          displayName: 'B2 – Conversational',
          cefrLevel: 'b2',
          voiceCallEnabled: true,
          ttsEnabled: true,
        ),
      ];

    await tester.pumpWidget(
      createLevelPickerTestApp(userRepo: userRepo, spaceRepo: spaceRepo),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('B2 – Conversational'));
    await tester.pumpAndSettle();

    expect(find.byType(SessionListScreen), findsOneWidget);
    expect(find.text('B2 – Conversational'), findsWidgets);
  });
}
