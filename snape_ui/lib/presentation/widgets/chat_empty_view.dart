import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class ChatEmptyView extends StatelessWidget {
  final VoidCallback? onStartPrompt;

  const ChatEmptyView({
    super.key,
    this.onStartPrompt,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64.r,
              height: 64.r,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.indigoSoftBackground,
              ),
              child: Icon(
                Icons.auto_stories_outlined,
                size: 32.r,
                color: AppColors.indigoAccent,
              ),
            ),
            SizedBox(height: AppSpacing.base.h),
            Text(
              'Your English Companion',
              style: AppTypography.titleMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.xs.h),
            Text(
              'Chat freely in English, Indonesian, or code-switch naturally. Snape softly models natural phrasing.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.slateSecondary,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.lg.h),
            _PromptSuggestionCard(
              prompt: 'Hey Snape, how was your day?',
              onTap: () => onStartPrompt?.call(),
            ),
            SizedBox(height: AppSpacing.xs.h),
            _PromptSuggestionCard(
              prompt: 'Bisa bantu latihan speaking buat interview?',
              onTap: () => onStartPrompt?.call(),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromptSuggestionCard extends StatelessWidget {
  final String prompt;
  final VoidCallback onTap;

  const _PromptSuggestionCard({
    required this.prompt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.base.w,
          vertical: AppSpacing.sm.h,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadii.md.r),
          border: Border.all(
            color: AppColors.dividerColor,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 16.r,
              color: AppColors.indigoAccent,
            ),
            SizedBox(width: AppSpacing.sm.w),
            Expanded(
              child: Text(
                prompt,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.slatePrimary,
                  fontSize: 13.sp,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
