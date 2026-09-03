import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/models/space.dart';

class ChatEmptyView extends StatelessWidget {
  final List<String>? starterPrompts;
  final SpaceModel? space;
  final ValueChanged<String>? onSelectPrompt;
  final VoidCallback? onStartPrompt;

  const ChatEmptyView({
    super.key,
    this.starterPrompts,
    this.space,
    this.onSelectPrompt,
    this.onStartPrompt,
  });

  static const List<String> _defaultPrompts = [
    'Hey Snape, how was your day?',
    'Bisa bantu latihan speaking buat interview?',
  ];

  @override
  Widget build(BuildContext context) {
    final prompts = (starterPrompts != null && starterPrompts!.isNotEmpty)
        ? starterPrompts!
        : (space != null && space!.starterPrompts.isNotEmpty)
            ? space!.starterPrompts
            : _defaultPrompts;

    final title = space?.displayName.isNotEmpty == true
        ? space!.displayName
        : 'Your English Companion';

    final subtitle = space != null && space!.cefrLevel == null
        ? 'Diskusikan topik ini bersama Snape, kembangkan wawasan dan pola pikir.'
        : 'Chat freely in English, Indonesian, or code-switch naturally. Snape softly models natural phrasing.';

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
              title,
              style: AppTypography.titleMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.xs.h),
            Text(
              subtitle,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.slateSecondary,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.lg.h),
            for (int i = 0; i < prompts.length; i++) ...[
              if (i > 0) SizedBox(height: AppSpacing.xs.h),
              _PromptSuggestionCard(
                prompt: prompts[i],
                onTap: () {
                  onSelectPrompt?.call(prompts[i]);
                  onStartPrompt?.call();
                },
              ),
            ],
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
