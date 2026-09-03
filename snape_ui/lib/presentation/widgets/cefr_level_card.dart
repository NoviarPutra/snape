import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class CefrLevelCard extends StatelessWidget {
  final String cefrCode;
  final String title;
  final String description;
  final bool isRecommended;
  final VoidCallback onTap;

  const CefrLevelCard({
    super.key,
    required this.cefrCode,
    required this.title,
    required this.description,
    this.isRecommended = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isRecommended ? AppColors.indigoSoftBackground : AppColors.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg.r),
        side: BorderSide(
          color: isRecommended ? AppColors.indigoAccent : AppColors.dividerColor,
          width: isRecommended ? 1.5 : 1,
        ),
      ),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.indigoSoftBackground,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.base.w,
            vertical: AppSpacing.md.h,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44.r,
                height: 44.r,
                decoration: BoxDecoration(
                  color: isRecommended
                      ? AppColors.indigoAccent
                      : AppColors.surfaceWarm,
                  borderRadius: BorderRadius.circular(AppRadii.md.r),
                ),
                alignment: Alignment.center,
                child: Text(
                  cefrCode,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: isRecommended ? Colors.white : AppColors.slatePrimary,
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.md.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: AppTypography.titleMedium.copyWith(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isRecommended) ...[
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.indigoAccent,
                              borderRadius:
                                  BorderRadius.circular(AppRadii.pill.r),
                            ),
                            child: Text(
                              'Recommended',
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      description,
                      style: AppTypography.bodyMedium.copyWith(
                        fontSize: 12.sp,
                        color: AppColors.slateSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: AppSpacing.sm.w),
              Icon(
                Icons.chevron_right_rounded,
                size: 20.r,
                color: isRecommended
                    ? AppColors.indigoAccent
                    : AppColors.slateTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
