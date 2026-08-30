import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../state/chat_state.dart';

class ConnectionStatusBanner extends StatelessWidget {
  final ConnectionStatus status;
  final String? errorMessage;
  final VoidCallback onRetry;

  const ConnectionStatusBanner({
    super.key,
    required this.status,
    this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (status == ConnectionStatus.connected && (errorMessage == null || errorMessage!.isEmpty)) {
      return const SizedBox.shrink();
    }

    final isReconnecting = status == ConnectionStatus.reconnecting;
    final isConnecting = status == ConnectionStatus.connecting;
    final isError = status == ConnectionStatus.disconnected || (errorMessage != null && errorMessage!.isNotEmpty);

    Color bgColor = AppColors.surfaceWarm;
    Color textColor = AppColors.slateSecondary;
    String message = 'Connecting to companion...';
    IconData icon = Icons.sync_rounded;

    if (isReconnecting) {
      bgColor = AppColors.surfaceWarm;
      textColor = AppColors.statusReconnecting;
      message = 'Reconnecting to stream...';
      icon = Icons.sync_problem_rounded;
    } else if (isConnecting) {
      bgColor = AppColors.indigoSoftBackground;
      textColor = AppColors.indigoAccent;
      message = 'Establishing live connection...';
      icon = Icons.cloud_sync_outlined;
    } else if (isError) {
      bgColor = AppColors.errorBackground;
      textColor = AppColors.statusError;
      message = errorMessage ?? 'Disconnected from companion stream';
      icon = Icons.wifi_off_rounded;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.base.w,
        vertical: AppSpacing.sm.h,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(
            color: isError ? AppColors.errorBorder : AppColors.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16.r,
            color: textColor,
          ),
          SizedBox(width: AppSpacing.sm.w),
          Expanded(
            child: Text(
              message,
              style: AppTypography.caption.copyWith(color: textColor),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isError) ...[
            SizedBox(width: AppSpacing.xs.w),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm.w,
                  vertical: AppSpacing.xxs.h,
                ),
                decoration: BoxDecoration(
                  color: AppColors.statusError.withAlpha(25),
                  borderRadius: BorderRadius.circular(AppRadii.sm.r),
                  border: Border.all(color: AppColors.errorBorder, width: 1),
                ),
                child: Text(
                  'Retry',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.statusError,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
