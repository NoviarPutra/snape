import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/models/space.dart';
import '../state/chat_notifier.dart';
import '../state/providers.dart';
import '../state/session_notifier.dart';
import '../widgets/featured_space_card.dart';
import '../widgets/space_grid_card.dart';
import '../widgets/trending_hero_banner.dart';
import 'chat_screen.dart';
import 'level_picker_screen.dart';
import 'news_portal_screen.dart';
import 'session_list_screen.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});

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
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  static const List<SpaceModel> _fallbackNonEnglishSpaces = [
    SpaceModel(
      slug: 'tech',
      displayName: 'Teknologi',
      cefrLevel: null,
      voiceCallEnabled: false,
      ttsEnabled: false,
    ),
    SpaceModel(
      slug: 'psychology',
      displayName: 'Psikologi',
      cefrLevel: null,
      voiceCallEnabled: false,
      ttsEnabled: false,
    ),
    SpaceModel(
      slug: 'productivity',
      displayName: 'Produktivitas',
      cefrLevel: null,
      voiceCallEnabled: false,
      ttsEnabled: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(spaceProvider.notifier).loadSpaces();
    });
  }

  void _navigateToLevelPicker() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LevelPickerScreen(),
      ),
    );
  }

  void _navigateToNewsPortal() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const NewsPortalScreen(),
      ),
    );
  }

  void _navigateToSpaceSessions(SpaceModel space) {
    ref.read(spaceProvider.notifier).selectSpace(space);
    ref.read(sessionProvider.notifier).loadSessions(spaceSlug: space.slug);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SessionListScreen(space: space),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spaceState = ref.watch(spaceProvider);

    final apiNonEnglish = spaceState.spaces
        .where((s) => s.cefrLevel == null && !s.slug.startsWith('english_'))
        .toList();
    final nonEnglishSpaces =
        apiNonEnglish.isNotEmpty ? apiNonEnglish : _fallbackNonEnglishSpaces;

    return Scaffold(
      backgroundColor: AppColors.parchmentBackground,
      appBar: AppBar(
        title: Text(
          'Snape',
          style: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
        elevation: 0,
      ),
      body: spaceState.isLoading && spaceState.spaces.isEmpty
          ? const Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.indigoAccent),
              ),
            )
          : spaceState.errorMessage != null && spaceState.spaces.isEmpty
              ? _buildErrorView(spaceState.errorMessage!)
              : _buildLobbyContent(nonEnglishSpaces),
    );
  }

  Widget _buildErrorView(String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl.r),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48.r,
              color: AppColors.statusError,
            ),
            SizedBox(height: AppSpacing.md.h),
            Text(
              'Unable to Load Spaces',
              style: AppTypography.titleMedium,
            ),
            SizedBox(height: AppSpacing.xs.h),
            Text(
              message,
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.lg.h),
            ElevatedButton.icon(
              onPressed: () => ref.read(spaceProvider.notifier).loadSpaces(),
              icon: Icon(Icons.refresh_rounded, size: 18.r),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.indigoAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.md.r),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLobbyContent(List<SpaceModel> nonEnglishSpaces) {
    return RefreshIndicator(
      color: AppColors.indigoAccent,
      onRefresh: () => ref.read(spaceProvider.notifier).loadSpaces(),
      child: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.base.w,
          vertical: AppSpacing.md.h,
        ),
        children: [
          Text(
            'Discussion Spaces',
            style: AppTypography.titleLarge.copyWith(
              fontSize: 22.sp,
            ),
          ),
          SizedBox(height: AppSpacing.xs.h),
          Text(
            'Select a specialized room to start a conversation with Snape.',
            style: AppTypography.bodyMedium.copyWith(
              fontSize: 13.sp,
            ),
          ),
          SizedBox(height: AppSpacing.base.h),
          FeaturedSpaceCard(
            onTap: _navigateToLevelPicker,
          ),
          SizedBox(height: AppSpacing.md.h),
          TrendingHeroBanner(
            onTap: _navigateToNewsPortal,
          ),
          SizedBox(height: AppSpacing.xl.h),
          Text(
            'Specialized Domains',
            style: AppTypography.titleMedium.copyWith(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: AppSpacing.xs.h),
          Text(
            'Deep technical & life discussions in Indonesian.',
            style: AppTypography.caption,
          ),
          SizedBox(height: AppSpacing.md.h),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: nonEnglishSpaces.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppSpacing.sm.w,
              mainAxisSpacing: AppSpacing.sm.h,
              childAspectRatio: 0.88,
            ),
            itemBuilder: (context, index) {
              final space = nonEnglishSpaces[index];
              return SpaceGridCard(
                space: space,
                onTap: () => _navigateToSpaceSessions(space),
              );
            },
          ),
          SizedBox(height: AppSpacing.xl.h),
        ],
      ),
    );
  }
}
