import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/models/space.dart';
import '../../domain/models/trending_article.dart';
import '../state/chat_notifier.dart';
import '../state/providers.dart';
import '../state/session_notifier.dart';
import '../widgets/trending_article_card.dart';
import 'chat_screen.dart';

class NewsPortalScreen extends ConsumerStatefulWidget {
  const NewsPortalScreen({super.key});

  @override
  ConsumerState<NewsPortalScreen> createState() => _NewsPortalScreenState();
}

class _NewsPortalScreenState extends ConsumerState<NewsPortalScreen> {
  static const List<Map<String, String?>> _categories = [
    {'label': 'All', 'value': null},
    {'label': 'Politics', 'value': 'politics'},
    {'label': 'General News', 'value': 'general'},
    {'label': 'Music', 'value': 'music'},
    {'label': 'Creator Trends', 'value': 'creator_trends'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(trendingProvider.notifier).loadArticles();
    });
  }

  Future<void> _handleEnglishDiscussion(TrendingArticleModel article) async {
    final prompt =
        "Let's discuss this trending news: \"${article.title}\".\n\nSummary:\n${article.summary}\n\nWhat are your key thoughts or perspective on this?";

    final spaceState = ref.read(spaceProvider);
    final targetSpace = spaceState.spaces
            .where((s) => s.slug == 'english_b2')
            .firstOrNull ??
        const SpaceModel(
          slug: 'english_b2',
          displayName: 'B2 – Conversational',
          cefrLevel: 'b2',
          voiceCallEnabled: true,
          ttsEnabled: true,
        );

    ref.read(spaceProvider.notifier).selectSpace(targetSpace);

    final session = await ref.read(sessionProvider.notifier).createSession(
          spaceSlug: 'english_b2',
          title: 'News: ${article.title}',
        );

    if (session != null && mounted) {
      await ref.read(chatProvider.notifier).switchSession(session.id);
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              sessionId: session.id,
              spaceSlug: 'english_b2',
              initialMessage: prompt,
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleIndonesianDiscussion(TrendingArticleModel article) async {
    final prompt =
        "Yuk kita bahas santai berita trending ini: \"${article.title}\".\n\nRingkasan:\n${article.summary}\n\nMenurutmu apa hal paling menarik dari topik ini?";

    final spaceState = ref.read(spaceProvider);
    final idSpace = spaceState.spaces
            .where((s) => s.cefrLevel == null && !s.slug.startsWith('english_'))
            .firstOrNull ??
        const SpaceModel(
          slug: 'tech',
          displayName: 'Teknologi',
          cefrLevel: null,
          voiceCallEnabled: false,
          ttsEnabled: false,
        );

    ref.read(spaceProvider.notifier).selectSpace(idSpace);

    final session = await ref.read(sessionProvider.notifier).createSession(
          spaceSlug: idSpace.slug,
          title: 'Diskusi: ${article.title}',
        );

    if (session != null && mounted) {
      await ref.read(chatProvider.notifier).switchSession(session.id);
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              sessionId: session.id,
              spaceSlug: idSpace.slug,
              initialMessage: prompt,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final trendingState = ref.watch(trendingProvider);

    // Listen for sync feedback
    ref.listen(trendingProvider, (previous, next) {
      if (next.syncStatusMessage != null &&
          next.syncStatusMessage != previous?.syncStatusMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.syncStatusMessage!),
            backgroundColor: AppColors.slatePrimary,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage &&
          next.articles.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.statusError,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.parchmentBackground,
      appBar: AppBar(
        title: Text(
          'News & Trends',
          style: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        actions: [
          if (trendingState.isSyncing)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.base.w),
              child: Center(
                child: SizedBox(
                  width: 20.r,
                  height: 20.r,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.indigoAccent,
                    ),
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.sync_rounded),
              tooltip: 'Sync Latest Trends',
              onPressed: () =>
                  ref.read(trendingProvider.notifier).syncArticles(),
            ),
        ],
      ),
      body: Column(
        children: [
          // Category selector bar
          _buildCategoryFilter(trendingState.selectedCategory),

          // Content area
          Expanded(
            child: trendingState.isLoading && trendingState.articles.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.indigoAccent,
                      ),
                    ),
                  )
                : trendingState.errorMessage != null &&
                        trendingState.articles.isEmpty
                    ? _buildErrorView(trendingState.errorMessage!)
                    : _buildArticlesList(trendingState),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter(String? selectedCategory) {
    return Container(
      height: 48.h,
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.base.w),
      decoration: const BoxDecoration(
        color: AppColors.parchmentBackground,
        border: Border(
          bottom: BorderSide(
            color: AppColors.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, _) => SizedBox(width: AppSpacing.xs.w),
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final catValue = cat['value'];
          final isSelected = selectedCategory == catValue;

          return Center(
            child: FilterChip(
              label: Text(
                cat['label']!,
                style: AppTypography.caption.copyWith(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : AppColors.slateSecondary,
                ),
              ),
              selected: isSelected,
              showCheckmark: false,
              selectedColor: AppColors.indigoAccent,
              backgroundColor: AppColors.surfaceWarm,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.pill.r),
                side: BorderSide(
                  color: isSelected
                      ? AppColors.indigoAccent
                      : AppColors.dividerColor,
                  width: 1,
                ),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.xs.w,
                vertical: 2.h,
              ),
              onSelected: (_) {
                ref.read(trendingProvider.notifier).selectCategory(catValue);
              },
            ),
          );
        },
      ),
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
              'Unable to Load News',
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
              onPressed: () =>
                  ref.read(trendingProvider.notifier).loadArticles(refresh: true),
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

  Widget _buildArticlesList(dynamic trendingState) {
    final articles = trendingState.articles as List<TrendingArticleModel>;

    if (articles.isEmpty) {
      return RefreshIndicator(
        color: AppColors.indigoAccent,
        onRefresh: () =>
            ref.read(trendingProvider.notifier).loadArticles(refresh: true),
        child: ListView(
          padding: EdgeInsets.all(AppSpacing.xl.r),
          children: [
            SizedBox(height: 60.h),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.newspaper_rounded,
                    size: 48.r,
                    color: AppColors.slateMuted,
                  ),
                  SizedBox(height: AppSpacing.md.h),
                  Text(
                    'No Trending Topics Yet',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.slatePrimary,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xs.h),
                  Text(
                    'Tap Sync to let Hermes discover and summarize breaking trends.',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.slateTertiary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: AppSpacing.lg.h),
                  ElevatedButton.icon(
                    onPressed: () =>
                        ref.read(trendingProvider.notifier).syncArticles(),
                    icon: Icon(Icons.sync_rounded, size: 18.r),
                    label: const Text('Discover Trends Now'),
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
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.indigoAccent,
      onRefresh: () =>
          ref.read(trendingProvider.notifier).loadArticles(refresh: true),
      child: ListView.builder(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.base.w,
          vertical: AppSpacing.md.h,
        ),
        itemCount: articles.length,
        itemBuilder: (context, index) {
          final article = articles[index];
          return TrendingArticleCard(
            article: article,
            onEnglishDiscussion: _handleEnglishDiscussion,
            onIndonesianDiscussion: _handleIndonesianDiscussion,
          );
        },
      ),
    );
  }
}
