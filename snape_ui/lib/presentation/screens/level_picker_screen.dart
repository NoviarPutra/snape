import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/models/space.dart';
import '../state/chat_notifier.dart';
import '../state/providers.dart';
import '../state/session_notifier.dart';
import '../widgets/cefr_level_card.dart';
import 'chat_screen.dart';
import 'session_list_screen.dart';

class _CefrLevelItem {
  final String code;
  final String title;
  final String description;

  const _CefrLevelItem({
    required this.code,
    required this.title,
    required this.description,
  });
}

class LevelPickerScreen extends ConsumerWidget {
  const LevelPickerScreen({super.key});

  static const List<_CefrLevelItem> _levels = [
    _CefrLevelItem(
      code: 'A1',
      title: 'A1 – Just Starting',
      description: 'Basic vocabulary & everyday expressions for beginners.',
    ),
    _CefrLevelItem(
      code: 'A2',
      title: 'A2 – Building Basics',
      description: 'Simple routines, familiar topics, and direct communication.',
    ),
    _CefrLevelItem(
      code: 'B1',
      title: 'B1 – Getting Comfortable',
      description: 'Connected conversations on work, hobbies, and personal thoughts.',
    ),
    _CefrLevelItem(
      code: 'B2',
      title: 'B2 – Conversational',
      description: 'Spontaneous, fluent discussion with natural soft corrections.',
    ),
    _CefrLevelItem(
      code: 'C1',
      title: 'C1 – Advanced',
      description: 'Complex ideas, nuance, idioms, and professional topics.',
    ),
    _CefrLevelItem(
      code: 'C2',
      title: 'C2 – Mastery',
      description: 'Native-like precision, subtle rhetoric, and deep analysis.',
    ),
  ];

  String _resolveRecommendedLevel(String? englishLevel) {
    if (englishLevel == null || englishLevel.isEmpty) return 'B2';
    final normalized = englishLevel.trim().toLowerCase();
    if (normalized.contains('a1') || normalized == 'beginner') return 'A1';
    if (normalized.contains('a2') || normalized == 'elementary') return 'A2';
    if (normalized.contains('b1')) return 'B1';
    if (normalized.contains('b2') || normalized.contains('intermediate')) {
      return 'B2';
    }
    if (normalized.contains('c1') || normalized == 'advanced') return 'C1';
    if (normalized.contains('c2') ||
        normalized.contains('mastery') ||
        normalized.contains('native')) {
      return 'C2';
    }
    return 'B2';
  }

  void _onSelectLevel(
      BuildContext context, WidgetRef ref, _CefrLevelItem item) {
    final slug = 'english_${item.code.toLowerCase()}';
    final spaceState = ref.read(spaceProvider);

    final matchingSpace = spaceState.spaces.firstWhere(
      (s) => s.slug == slug,
      orElse: () => SpaceModel(
        slug: slug,
        displayName: item.title,
        cefrLevel: item.code.toLowerCase(),
        voiceCallEnabled: true,
        ttsEnabled: true,
      ),
    );

    ref.read(spaceProvider.notifier).selectSpace(matchingSpace);
    ref.read(sessionProvider.notifier).loadSessions(spaceSlug: matchingSpace.slug);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SessionListScreen(space: matchingSpace),
      ),
    );
  }

  static Future<void> preResolveAndNavigateToChat(
    BuildContext context,
    WidgetRef ref,
    SpaceModel space,
  ) async {
    ref.read(spaceProvider.notifier).selectSpace(space);
    final session =
        await ref.read(sessionProvider.notifier).ensureActiveSession(
              spaceSlug: space.slug,
              defaultTitle: space.displayName,
            );
    if (context.mounted) {
      await ref.read(chatProvider.notifier).switchSession(session.id);
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              sessionId: session.id,
              spaceSlug: space.slug,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileProvider);
    final userLevel = userProfileAsync.valueOrNull?.englishLevel;
    final recommendedLevelCode = _resolveRecommendedLevel(userLevel);

    return Scaffold(
      backgroundColor: AppColors.parchmentBackground,
      appBar: AppBar(
        title: Text(
          'English Learning Levels',
          style: AppTypography.titleMedium,
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, size: 22.r),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.base.w,
          vertical: AppSpacing.md.h,
        ),
        children: [
          Text(
            'Select CEFR Proficiency',
            style: AppTypography.titleLarge.copyWith(
              fontSize: 20.sp,
            ),
          ),
          SizedBox(height: AppSpacing.xs.h),
          Text(
            'Snape adjusts language complexity, speaking speed, and correction style to your selected level.',
            style: AppTypography.bodyMedium.copyWith(
              fontSize: 13.sp,
            ),
          ),
          SizedBox(height: AppSpacing.base.h),
          ..._levels.map((item) {
            final isRecommended = item.code == recommendedLevelCode;
            return Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm.h),
              child: CefrLevelCard(
                cefrCode: item.code,
                title: item.title,
                description: item.description,
                isRecommended: isRecommended,
                onTap: () => _onSelectLevel(context, ref, item),
              ),
            );
          }),
          SizedBox(height: AppSpacing.lg.h),
        ],
      ),
    );
  }
}
