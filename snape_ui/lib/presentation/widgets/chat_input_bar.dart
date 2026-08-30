import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class ChatInputBar extends StatefulWidget {
  final ValueChanged<String> onSendMessage;
  final bool isStreaming;
  final VoidCallback? onMicTap;
  final bool isRecording;

  const ChatInputBar({
    super.key,
    required this.onSendMessage,
    this.isStreaming = false,
    this.onMicTap,
    this.isRecording = false,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  late final TextEditingController _controller;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(() {
      final hasTextNow = _controller.text.trim().isNotEmpty;
      if (hasTextNow != _hasText) {
        setState(() {
          _hasText = hasTextNow;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isStreaming) return;
    widget.onSendMessage(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.base.w,
        right: AppSpacing.base.w,
        top: AppSpacing.sm.h,
        bottom: MediaQuery.of(context).padding.bottom > 0
            ? MediaQuery.of(context).padding.bottom
            : AppSpacing.md.h,
      ),
      decoration: const BoxDecoration(
        color: AppColors.parchmentBackground,
        border: Border(
          top: BorderSide(
            color: AppColors.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Audio Recording Hook Toggle Button
          IconButton(
            onPressed: widget.onMicTap ?? () {},
            icon: Icon(
              widget.isRecording ? Icons.mic : Icons.mic_none_rounded,
              color: widget.isRecording
                  ? AppColors.micRecording
                  : AppColors.micIdle,
              size: 22.r,
            ),
            splashRadius: 20.r,
            tooltip: widget.isRecording ? 'Stop Recording' : 'Voice Input (Hook)',
          ),
          SizedBox(width: AppSpacing.xs.w),
          // Text Input Field
          Expanded(
            child: Container(
              constraints: BoxConstraints(
                minHeight: 40.h,
                maxHeight: 120.h,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(AppRadii.xl.r),
                border: Border.all(
                  color: AppColors.dividerColor,
                  width: 1,
                ),
              ),
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.base.w),
              child: Center(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSubmit(),
                  style: AppTypography.input,
                  decoration: InputDecoration(
                    hintText: 'Speak or type in English (or campur)...',
                    hintStyle: AppTypography.bodyMedium.copyWith(
                      color: AppColors.slateMuted,
                      fontSize: 14.sp,
                    ),
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10.h),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: AppSpacing.sm.w),
          // Send Action Button
          Container(
            width: 40.r,
            height: 40.r,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (_hasText && !widget.isStreaming)
                  ? AppColors.indigoAccent
                  : AppColors.surfaceWarm,
            ),
            child: IconButton(
              icon: Icon(
                Icons.arrow_upward_rounded,
                color: (_hasText && !widget.isStreaming)
                    ? Colors.white
                    : AppColors.slateMuted,
                size: 20.r,
              ),
              onPressed: (_hasText && !widget.isStreaming) ? _handleSubmit : null,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}
