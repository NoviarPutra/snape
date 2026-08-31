import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/models/memory_item.dart';
import '../state/providers.dart';

class MemoryDrawer extends ConsumerWidget {
  const MemoryDrawer({super.key});

  static const List<String> _categories = [
    'ALL',
    'FACT',
    'PREFERENCE',
    'GOAL',
    'EXPERIENCE',
  ];

  Color _categoryColor(String category) {
    switch (category.toUpperCase()) {
      case 'FACT':
        return AppColors.indigoAccent;
      case 'PREFERENCE':
        return const Color(0xFF2E7D32);
      case 'GOAL':
        return const Color(0xFFB7791F);
      case 'EXPERIENCE':
        return const Color(0xFF6B46C1);
      default:
        return AppColors.slateSecondary;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category.toUpperCase()) {
      case 'FACT':
        return Icons.info_outline_rounded;
      case 'PREFERENCE':
        return Icons.favorite_outline_rounded;
      case 'GOAL':
        return Icons.flag_outlined;
      case 'EXPERIENCE':
        return Icons.history_edu_rounded;
      default:
        return Icons.bookmark_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memoryState = ref.watch(memoryProvider);
    final memoryNotifier = ref.read(memoryProvider.notifier);

    return Drawer(
      backgroundColor: AppColors.parchmentBackground,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.base.w,
                vertical: AppSpacing.md.h,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.psychology_outlined,
                    size: 24.r,
                    color: AppColors.indigoAccent,
                  ),
                  SizedBox(width: AppSpacing.sm.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Snape\'s Memory',
                          style: AppTypography.titleMedium,
                        ),
                        Text(
                          'Learned from your conversations',
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.refresh_rounded,
                      size: 22.r,
                      color: AppColors.indigoAccent,
                    ),
                    tooltip: 'Refresh Memories',
                    onPressed: () {
                      memoryNotifier.refresh();
                      ref.invalidate(userMemoriesProvider);
                    },
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.dividerColor, height: 1),
            // Category Filter Bar
            SizedBox(
              height: 44.h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.base.w,
                  vertical: AppSpacing.xs.h,
                ),
                itemCount: _categories.length,
                separatorBuilder: (context, index) =>
                    SizedBox(width: AppSpacing.xs.w),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isAll = cat == 'ALL';
                  final isSelected = isAll
                      ? (memoryState.selectedCategory == null ||
                          memoryState.selectedCategory!.isEmpty)
                      : (memoryState.selectedCategory?.toUpperCase() == cat);

                  return Material(
                    color: isSelected
                        ? AppColors.indigoAccent
                        : AppColors.surfaceWarm,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.xs.r),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.indigoAccent
                            : AppColors.dividerColor,
                        width: 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        memoryNotifier.selectCategory(isAll ? null : cat.toLowerCase());
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm.w,
                          vertical: 4.h,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : AppColors.slateSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(color: AppColors.dividerColor, height: 1),
            // Content List
            Expanded(
              child: memoryState.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.indigoAccent),
                      ),
                    )
                  : memoryState.hasError
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(AppSpacing.base.w),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: AppColors.statusError,
                                  size: 36.r,
                                ),
                                SizedBox(height: AppSpacing.sm.h),
                                Text(
                                  memoryState.errorMessage ?? 'Error',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.bodyMedium,
                                ),
                                SizedBox(height: AppSpacing.md.h),
                                ElevatedButton.icon(
                                  onPressed: () => memoryNotifier.refresh(),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.indigoAccent,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : memoryState.filteredMemories.isEmpty
                          ? Center(
                              child: Padding(
                                padding: EdgeInsets.all(AppSpacing.xl.w),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.lightbulb_outline,
                                      size: 42.r,
                                      color: AppColors.slateMuted,
                                    ),
                                    SizedBox(height: AppSpacing.sm.h),
                                    Text(
                                      'No memories stored yet',
                                      style: AppTypography.titleMedium.copyWith(
                                        color: AppColors.slateSecondary,
                                        fontSize: 15.sp,
                                      ),
                                    ),
                                    SizedBox(height: AppSpacing.xs.h),
                                    Text(
                                      'As you chat, Snape naturally remembers your background, preferences, and learning goals.',
                                      textAlign: TextAlign.center,
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.slateTertiary,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: EdgeInsets.all(AppSpacing.base.w),
                              itemCount: memoryState.filteredMemories.length,
                              separatorBuilder: (context, index) =>
                                  SizedBox(height: AppSpacing.sm.h),
                              itemBuilder: (context, index) {
                                final memory =
                                    memoryState.filteredMemories[index];
                                return _MemoryCard(
                                  memory: memory,
                                  categoryColor:
                                      _categoryColor(memory.category),
                                  categoryIcon: _categoryIcon(memory.category),
                                  onDelete: () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Delete Memory?'),
                                        content: Text(
                                          'Are you sure you want Snape to forget "${memory.content}"?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(ctx).pop(false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(ctx).pop(true),
                                            style: TextButton.styleFrom(
                                              foregroundColor:
                                                  AppColors.statusError,
                                            ),
                                            child: const Text('Forget'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirmed == true) {
                                      await memoryNotifier
                                          .deleteMemory(memory.id);
                                    }
                                  },
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  final MemoryItem memory;
  final Color categoryColor;
  final IconData categoryIcon;
  final VoidCallback onDelete;

  const _MemoryCard({
    required this.memory,
    required this.categoryColor,
    required this.categoryIcon,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final formattedDate =
        DateFormat('MMM d, yyyy • h:mm a').format(memory.createdAt);

    return Container(
      padding: EdgeInsets.all(AppSpacing.sm.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadii.sm.r),
        border: Border.all(color: AppColors.dividerColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 4.r,
            offset: Offset(0, 1.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs.w,
                    vertical: 2.h,
                  ),
                  decoration: BoxDecoration(
                    color: categoryColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(AppRadii.xs.r),
                    border: Border.all(
                      color: categoryColor.withAlpha(80),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(categoryIcon, size: 12.r, color: categoryColor),
                      SizedBox(width: 3.w),
                      Flexible(
                        child: Text(
                          memory.category.toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                            color: categoryColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 16.r,
                  color: AppColors.slateTertiary,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Forget memory',
                onPressed: onDelete,
              ),
            ],
          ),
          SizedBox(height: AppSpacing.xs.h),
          Text(
            memory.content,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.slatePrimary,
              fontWeight: FontWeight.w400,
            ),
          ),
          SizedBox(height: AppSpacing.xs.h),
          Text(
            formattedDate,
            style: AppTypography.caption.copyWith(
              fontSize: 10.sp,
              color: AppColors.slateTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
