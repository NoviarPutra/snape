import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class FeaturedSpaceCard extends StatelessWidget {
  final VoidCallback onTap;

  const FeaturedSpaceCard({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg.r),
        side: const BorderSide(
          color: AppColors.dividerColor,
          width: 1,
        ),
      ),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.indigoSoftBackground,
        highlightColor: AppColors.indigoSoftBackground.withValues(alpha: 0.5),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.base.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44.r,
                    height: 44.r,
                    decoration: BoxDecoration(
                      color: AppColors.indigoSoftBackground,
                      borderRadius: BorderRadius.circular(AppRadii.md.r),
                    ),
                    child: Icon(
                      Icons.translate_rounded,
                      color: AppColors.indigoAccent,
                      size: 24.r,
                    ),
                  ),
                  SizedBox(width: AppSpacing.md.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: AppSpacing.xs.w,
                          runSpacing: AppSpacing.xs.h,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm.w,
                                vertical: AppSpacing.xxs.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.indigoSoftBackground,
                                borderRadius:
                                    BorderRadius.circular(AppRadii.pill.r),
                              ),
                              child: Text(
                                'FEATURED',
                                style: AppTypography.badge.copyWith(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm.w,
                                vertical: AppSpacing.xxs.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceWarm,
                                borderRadius:
                                    BorderRadius.circular(AppRadii.pill.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.mic_none_rounded,
                                    size: 11.r,
                                    color: AppColors.slateSecondary,
                                  ),
                                  SizedBox(width: 2.w),
                                  Text(
                                    'Voice & TTS',
                                    style: AppTypography.caption.copyWith(
                                      fontSize: 10.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: AppSpacing.xs.h),
                        Text(
                          'English Learning Companion',
                          style: AppTypography.titleLarge.copyWith(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.sm.h),
              Text(
                'Personalized English conversation practice tailored to your CEFR level with real-time soft corrections.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.slateSecondary,
                  fontSize: 13.sp,
                ),
              ),
              SizedBox(height: AppSpacing.md.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      '6 CEFR Levels (A1 – C2)',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.indigoAccent,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm.w),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Choose Level',
                        style: AppTypography.bodyLarge.copyWith(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.indigoAccent,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 16.r,
                        color: AppColors.indigoAccent,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
