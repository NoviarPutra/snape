import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/models/space.dart';

class SpaceGridCard extends StatelessWidget {
  final SpaceModel space;
  final VoidCallback onTap;

  const SpaceGridCard({
    super.key,
    required this.space,
    required this.onTap,
  });

  IconData _getIconForSlug(String slug) {
    switch (slug) {
      case 'tech':
        return Icons.terminal_rounded;
      case 'psychology':
        return Icons.psychology_outlined;
      case 'productivity':
        return Icons.trending_up_rounded;
      default:
        return Icons.forum_outlined;
    }
  }

  String _getDescriptionForSlug(String slug) {
    switch (slug) {
      case 'tech':
        return 'Software engineering, system architecture, & programming';
      case 'psychology':
        return 'Mental models, cognitive biases, & human behavior';
      case 'productivity':
        return 'Time management, deep work habits, & workflows';
      default:
        return 'Specialized Indonesian discussion space with expert persona.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = _getIconForSlug(space.slug);
    final description = _getDescriptionForSlug(space.slug);

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
          padding: EdgeInsets.all(AppSpacing.md.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 36.r,
                    height: 36.r,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWarm,
                      borderRadius: BorderRadius.circular(AppRadii.md.r),
                    ),
                    child: Icon(
                      icon,
                      color: AppColors.slatePrimary,
                      size: 20.r,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs.w,
                      vertical: 2.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWarm,
                      borderRadius: BorderRadius.circular(AppRadii.pill.r),
                    ),
                    child: Text(
                      'ID • Text',
                      style: AppTypography.caption.copyWith(
                        fontSize: 9.sp,
                        color: AppColors.slateTertiary,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.sm.h),
              Text(
                space.displayName,
                style: AppTypography.titleMedium.copyWith(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 2.h),
              Expanded(
                child: Text(
                  description,
                  style: AppTypography.bodyMedium.copyWith(
                    fontSize: 11.sp,
                    color: AppColors.slateSecondary,
                    height: 1.3,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 16.r,
                  color: AppColors.slateTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
