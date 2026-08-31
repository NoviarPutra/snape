import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../state/voice_call_state.dart';

class VoiceSubtitleCard extends StatelessWidget {
  final String userSpeech;
  final String assistantSpeech;
  final VoiceCallPhase phase;
  final bool isVisible;
  final VoidCallback? onToggleVisibility;

  const VoiceSubtitleCard({
    super.key,
    required this.userSpeech,
    required this.assistantSpeech,
    required this.phase,
    this.isVisible = true,
    this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasUserSpeech = userSpeech.trim().isNotEmpty;
    final bool hasAssistantSpeech = assistantSpeech.trim().isNotEmpty;

    return AnimatedOpacity(
      key: const Key('voice_subtitle_animated_opacity'),
      opacity: isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: IgnorePointer(
        ignoring: !isVisible,
        child: Container(
          width: double.infinity,
          margin: EdgeInsets.symmetric(horizontal: AppSpacing.base.w),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(AppRadii.lg.r),
            border: Border.all(
              color: AppColors.dividerColor.withValues(alpha: 0.8),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.slatePrimary.withValues(alpha: 0.08),
                blurRadius: 16.r,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.lg.r),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.base.w,
                  vertical: AppSpacing.md.h,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!hasUserSpeech && !hasAssistantSpeech)
                      _buildPlaceholder()
                    else ...[
                      if (hasUserSpeech) _buildUserSection(),
                      if (hasUserSpeech && hasAssistantSpeech)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.sm.h),
                          child: Divider(
                            height: 1.0,
                            thickness: 0.5,
                            color: AppColors.dividerColor,
                          ),
                        ),
                      if (hasAssistantSpeech) _buildAssistantSection(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    String text;
    IconData icon;

    switch (phase) {
      case VoiceCallPhase.listening:
        text = 'Listening...';
        icon = Icons.mic_none_rounded;
        break;
      case VoiceCallPhase.thinking:
        text = 'Thinking...';
        icon = Icons.auto_awesome_rounded;
        break;
      case VoiceCallPhase.speaking:
        text = 'Speaking...';
        icon = Icons.volume_up_rounded;
        break;
      case VoiceCallPhase.greeting:
        text = 'Starting conversation...';
        icon = Icons.waving_hand_outlined;
        break;
      case VoiceCallPhase.idle:
        text = 'Tap to speak';
        icon = Icons.mic_off_outlined;
        break;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 16.r,
          color: AppColors.slateTertiary,
        ),
        SizedBox(width: AppSpacing.sm.w),
        Text(
          text,
          style: AppTypography.caption.copyWith(
            color: AppColors.slateTertiary,
            fontSize: 13.sp,
          ),
        ),
      ],
    );
  }

  Widget _buildUserSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.xs.w,
                vertical: AppSpacing.xxs.h,
              ),
              decoration: BoxDecoration(
                color: AppColors.userBubbleBg,
                borderRadius: BorderRadius.circular(AppRadii.xs.r),
              ),
              child: Text(
                'You',
                style: AppTypography.badge.copyWith(
                  color: AppColors.userText,
                  fontSize: 10.sp,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.xs.h),
        Text(
          userSpeech,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.slatePrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildAssistantSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.xs.w,
                vertical: AppSpacing.xxs.h,
              ),
              decoration: BoxDecoration(
                color: AppColors.indigoSoftBackground,
                borderRadius: BorderRadius.circular(AppRadii.xs.r),
              ),
              child: Text(
                'Snape',
                style: AppTypography.badge.copyWith(
                  color: AppColors.indigoAccent,
                  fontSize: 10.sp,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.xs.h),
        Text(
          assistantSpeech,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.slatePrimary,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}
