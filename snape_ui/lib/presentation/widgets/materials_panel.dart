import 'package:flutter/material.dart' hide MaterialState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/models/material_item.dart';
import '../state/material_state.dart';
import '../state/providers.dart';

class MaterialsPanel extends ConsumerStatefulWidget {
  final String spaceSlug;
  final String? cefrLevel;
  final String? displayName;

  const MaterialsPanel({
    super.key,
    required this.spaceSlug,
    this.cefrLevel,
    this.displayName,
  });

  static Future<void> show(
    BuildContext context, {
    required String spaceSlug,
    String? cefrLevel,
    String? displayName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MaterialsPanel(
        spaceSlug: spaceSlug,
        cefrLevel: cefrLevel,
        displayName: displayName,
      ),
    );
  }

  @override
  ConsumerState<MaterialsPanel> createState() => _MaterialsPanelState();
}

class _MaterialsPanelState extends ConsumerState<MaterialsPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(materialProvider.notifier);
      final currentCategory = ref.read(materialProvider).selectedCategory;
      notifier.selectCategory(widget.spaceSlug, currentCategory);
    });
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  void _onSelectTab(MaterialCategory category) {
    ref.read(materialProvider.notifier).selectCategory(widget.spaceSlug, category);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(materialProvider);

    if (state.isLoading) {
      if (!_shimmerController.isAnimating) {
        _shimmerController.repeat(reverse: true);
      }
    } else {
      if (_shimmerController.isAnimating) {
        _shimmerController.stop();
      }
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: BoxDecoration(
        color: AppColors.parchmentBackground,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.xl.r),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDragHandle(),
          _buildHeader(context),
          _buildCategoryTabs(state.selectedCategory),
          Expanded(
            child: _buildBody(state),
          ),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        margin: EdgeInsets.only(top: AppSpacing.sm.h, bottom: AppSpacing.xs.h),
        width: 38.w,
        height: 4.h,
        decoration: BoxDecoration(
          color: AppColors.dividerColor,
          borderRadius: BorderRadius.circular(AppRadii.pill.r),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md.w,
        vertical: AppSpacing.xs.h,
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(AppSpacing.xs.r),
            decoration: BoxDecoration(
              color: AppColors.indigoSoftBackground,
              borderRadius: BorderRadius.circular(AppRadii.sm.r),
            ),
            child: Icon(
              Icons.menu_book_rounded,
              size: 20.r,
              color: AppColors.indigoAccent,
            ),
          ),
          SizedBox(width: AppSpacing.sm.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'Materi Referensi',
                        style: AppTypography.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.cefrLevel != null) ...[
                      SizedBox(width: AppSpacing.xs.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs.w * 1.5,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.indigoAccent,
                          borderRadius: BorderRadius.circular(AppRadii.xs.r),
                        ),
                        child: Text(
                          widget.cefrLevel!.toUpperCase(),
                          style: AppTypography.badge.copyWith(
                            color: Colors.white,
                            fontSize: 10.sp,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (widget.displayName != null)
                  Text(
                    widget.displayName!,
                    style: AppTypography.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              size: 20.r,
              color: AppColors.slateSecondary,
            ),
            tooltip: 'Tutup',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs(MaterialCategory selectedCategory) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md.w,
        vertical: AppSpacing.xs.h,
      ),
      child: Container(
        padding: EdgeInsets.all(AppSpacing.xxs.r),
        decoration: BoxDecoration(
          color: AppColors.surfaceWarm,
          borderRadius: BorderRadius.circular(AppRadii.md.r),
          border: Border.all(color: AppColors.dividerColor),
        ),
        child: Row(
          children: MaterialCategory.values.map((category) {
            final isSelected = category == selectedCategory;
            return Expanded(
              child: GestureDetector(
                onTap: () => _onSelectTab(category),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.surfaceCard : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadii.sm.r),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      category.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? AppColors.indigoAccent
                            : AppColors.slateSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBody(MaterialState state) {
    if (state.isLoading) {
      return _buildShimmerLoading();
    }

    if (state.errorMessage != null) {
      return _buildErrorState(state.errorMessage!);
    }

    if (state.isCurrentCategoryEmpty) {
      return _buildEmptyState();
    }

    final content = state.currentContent;
    if (content == null || content.trim().isEmpty) {
      return _buildEmptyState();
    }

    return _buildContent(content);
  }

  Widget _buildShimmerLoading() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        final opacity = 0.4 + (_shimmerController.value * 0.4);
        return Padding(
          padding: EdgeInsets.all(AppSpacing.md.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 140.w,
                height: 18.h,
                decoration: BoxDecoration(
                  color: AppColors.surfaceWarm.withValues(alpha: opacity),
                  borderRadius: BorderRadius.circular(AppRadii.xs.r),
                ),
              ),
              SizedBox(height: AppSpacing.md.h),
              Container(
                width: double.infinity,
                height: 12.h,
                decoration: BoxDecoration(
                  color: AppColors.surfaceWarm.withValues(alpha: opacity),
                  borderRadius: BorderRadius.circular(AppRadii.xs.r),
                ),
              ),
              SizedBox(height: AppSpacing.sm.h),
              Container(
                width: 260.w,
                height: 12.h,
                decoration: BoxDecoration(
                  color: AppColors.surfaceWarm.withValues(alpha: opacity),
                  borderRadius: BorderRadius.circular(AppRadii.xs.r),
                ),
              ),
              SizedBox(height: AppSpacing.sm.h),
              Container(
                width: double.infinity,
                height: 12.h,
                decoration: BoxDecoration(
                  color: AppColors.surfaceWarm.withValues(alpha: opacity),
                  borderRadius: BorderRadius.circular(AppRadii.xs.r),
                ),
              ),
              SizedBox(height: AppSpacing.md.h),
              Container(
                width: 180.w,
                height: 16.h,
                decoration: BoxDecoration(
                  color: AppColors.surfaceWarm.withValues(alpha: opacity),
                  borderRadius: BorderRadius.circular(AppRadii.xs.r),
                ),
              ),
              SizedBox(height: AppSpacing.sm.h),
              Container(
                width: double.infinity,
                height: 12.h,
                decoration: BoxDecoration(
                  color: AppColors.surfaceWarm.withValues(alpha: opacity),
                  borderRadius: BorderRadius.circular(AppRadii.xs.r),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(AppSpacing.md.r),
              decoration: BoxDecoration(
                color: AppColors.surfaceWarm,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_stories_outlined,
                size: 36.r,
                color: AppColors.slateMuted,
              ),
            ),
            SizedBox(height: AppSpacing.md.h),
            Text(
              'Materi untuk level ini belum tersedia',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.slateSecondary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(AppSpacing.sm.r),
              decoration: BoxDecoration(
                color: AppColors.errorBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 32.r,
                color: AppColors.statusError,
              ),
            ),
            SizedBox(height: AppSpacing.sm.h),
            Text(
              error,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.statusError,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: AppSpacing.md.h),
            ElevatedButton.icon(
              onPressed: () =>
                  ref.read(materialProvider.notifier).retry(widget.spaceSlug),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.indigoAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.sm.r),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md.w,
                  vertical: AppSpacing.xs.h,
                ),
              ),
              icon: Icon(Icons.refresh_rounded, size: 16.r),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(String content) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        AppSpacing.md.w,
        AppSpacing.xs.h,
        AppSpacing.md.w,
        AppSpacing.md.h,
      ),
      padding: EdgeInsets.all(AppSpacing.md.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadii.md.r),
        border: Border.all(color: AppColors.dividerColor),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: SelectableText(
          content,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 13.sp,
            color: AppColors.slatePrimary,
            height: 1.55,
          ),
        ),
      ),
    );
  }
}
