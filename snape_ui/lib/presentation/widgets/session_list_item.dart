import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/models/session.dart';

class SessionListItem extends StatelessWidget {
  final SessionModel session;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const SessionListItem({
    super.key,
    required this.session,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('MMM d, yyyy • h:mm a').format(session.createdAt);

    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.sm.h),
      child: Material(
        color: isSelected
            ? AppColors.indigoSoftBackground
            : AppColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md.r),
          side: BorderSide(
            color: isSelected
                ? AppColors.indigoAccentLight
                : AppColors.dividerColor,
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppSpacing.base.w,
            vertical: AppSpacing.xs.h,
          ),
          onTap: onTap,
          title: Text(
            session.title,
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? AppColors.indigoAccent
                  : AppColors.slatePrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Padding(
            padding: EdgeInsets.only(top: 4.h),
            child: Text(
              dateStr,
              style: AppTypography.caption,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 20.r,
                  color: AppColors.slateTertiary,
                ),
                tooltip: 'Delete Session',
                onPressed: onDelete,
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20.r,
                color: AppColors.slateTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
