import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/models/chat_message.dart';
import 'typing_indicator.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final timeString = DateFormat('h:mm a').format(message.createdAt);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: AppSpacing.base.w,
          vertical: AppSpacing.xs.h,
        ),
        constraints: BoxConstraints(
          maxWidth: 0.78.sw,
        ),
        decoration: BoxDecoration(
          color: isUser ? AppColors.userBubbleBg : AppColors.companionBubbleBg,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(AppRadii.lg.r),
            topRight: Radius.circular(AppRadii.lg.r),
            bottomLeft: Radius.circular(isUser ? AppRadii.lg.r : AppRadii.xs.r),
            bottomRight: Radius.circular(isUser ? AppRadii.xs.r : AppRadii.lg.r),
          ),
          border: isUser
              ? null
              : Border.all(
                  color: AppColors.companionBubbleBorder,
                  width: 1,
                ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isUser ? 10 : 6),
              blurRadius: 4.r,
              offset: Offset(0, 2.h),
            ),
          ],
        ),
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.base.w,
          vertical: AppSpacing.md.h,
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isUser) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6.r,
                    height: 6.r,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.indigoAccent,
                    ),
                  ),
                  SizedBox(width: AppSpacing.xs.w),
                  Text(
                    'Snape',
                    style: AppTypography.badge.copyWith(fontSize: 11.sp),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.xs.h),
            ],
            if (message.content.isEmpty && message.isStreaming) ...[
              Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xs.h),
                child: const TypingIndicator(),
              ),
            ] else ...[
              Text(
                message.content,
                style: isUser
                    ? AppTypography.userMessage
                    : AppTypography.bodyLarge,
              ),
            ],
            if (!isUser && message.extractedMemories.isNotEmpty) ...[
              SizedBox(height: AppSpacing.xs.h),
              Wrap(
                spacing: AppSpacing.xxs.w,
                runSpacing: AppSpacing.xxs.h,
                children: message.extractedMemories.map((mem) {
                  return Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs.w,
                      vertical: 2.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.indigoSoftBackground,
                      borderRadius: BorderRadius.circular(AppRadii.xs.r),
                      border: Border.all(
                        color: AppColors.indigoAccentLight.withAlpha(80),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 11.r,
                          color: AppColors.indigoAccent,
                        ),
                        SizedBox(width: 3.w),
                        Flexible(
                          child: Text(
                            'Remembered: $mem',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.indigoAccent,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
            SizedBox(height: AppSpacing.xs.h),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.isStreaming) ...[
                  Container(
                    margin: EdgeInsets.only(right: AppSpacing.xs.w),
                    width: 8.r,
                    height: 8.r,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5.r,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.indigoAccent,
                      ),
                    ),
                  ),
                ],
                Text(
                  timeString,
                  style: AppTypography.caption.copyWith(
                    color: isUser
                        ? AppColors.slateMuted.withAlpha(200)
                        : AppColors.slateTertiary,
                    fontSize: 10.sp,
                  ),
                ),
                if (message.status == MessageStatus.error) ...[
                  SizedBox(width: AppSpacing.xxs.w),
                  Icon(
                    Icons.error_outline,
                    size: 12.r,
                    color: AppColors.statusError,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
