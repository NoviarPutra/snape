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
  final VoidCallback? onVoiceCallTap;
  final bool isRecording;
  final bool showMicButton;
  final TextEditingController? controller;

  const ChatInputBar({
    super.key,
    required this.onSendMessage,
    this.isStreaming = false,
    this.onMicTap,
    this.onVoiceCallTap,
    this.isRecording = false,
    this.showMicButton = false,
    this.controller,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  TextEditingController? _internalController;
  TextEditingController get _effectiveController =>
      widget.controller ?? (_internalController ??= TextEditingController());

  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _effectiveController.addListener(_handleTextChange);
    _hasText = _effectiveController.text.trim().isNotEmpty;
  }

  @override
  void didUpdateWidget(covariant ChatInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_handleTextChange);
      _effectiveController.addListener(_handleTextChange);
      _handleTextChange();
    }
  }

  void _handleTextChange() {
    final hasTextNow = _effectiveController.text.trim().isNotEmpty;
    if (hasTextNow != _hasText) {
      if (mounted) {
        setState(() {
          _hasText = hasTextNow;
        });
      }
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_handleTextChange);
    _internalController?.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final text = _effectiveController.text.trim();
    if (text.isEmpty || widget.isStreaming) return;
    widget.onSendMessage(text);
    _effectiveController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final buttonSize = 40.r;

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.base.w,
        right: AppSpacing.base.w,
        top: AppSpacing.sm.h,
        bottom: MediaQuery.of(context).padding.bottom > 0
            ? MediaQuery.of(context).padding.bottom + 4.h
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
          // Optional Voice Input Mic Button (Hidden by default)
          if (widget.showMicButton) ...[
            Container(
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isRecording
                    ? AppColors.micRecording.withValues(alpha: 0.15)
                    : AppColors.surfaceCard,
                border: Border.all(
                  color: widget.isRecording
                      ? AppColors.micRecording
                      : AppColors.dividerColor,
                  width: 1,
                ),
              ),
              child: IconButton(
                onPressed: widget.onMicTap,
                padding: EdgeInsets.zero,
                icon: Icon(
                  widget.isRecording ? Icons.mic : Icons.mic_none_rounded,
                  color: widget.isRecording
                      ? AppColors.micRecording
                      : AppColors.slateMuted,
                  size: 20.r,
                ),
                tooltip: widget.isRecording ? 'Stop Recording' : 'Voice Input',
              ),
            ),
            SizedBox(width: AppSpacing.xs.w),
          ],
          // Text Input Field (Full width, expands dynamically with multiline text)
          Expanded(
            child: Container(
              constraints: BoxConstraints(
                minHeight: buttonSize,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(AppRadii.xl.r),
                border: Border.all(
                  color: AppColors.dividerColor,
                  width: 1,
                ),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              alignment: Alignment.centerLeft,
              child: TextField(
                controller: _effectiveController,
                minLines: 1,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                style: AppTypography.input,
                textAlignVertical: TextAlignVertical.center,
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
          SizedBox(width: AppSpacing.xs.w),
          // Send / Quick Voice Call Action Button
          Builder(
            builder: (context) {
              final isSendActive = _hasText && !widget.isStreaming;
              final isVoiceCallActive = !_hasText && !widget.isStreaming && widget.onVoiceCallTap != null;

              return Container(
                width: buttonSize,
                height: buttonSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSendActive
                      ? AppColors.indigoAccent
                      : (isVoiceCallActive
                          ? AppColors.indigoAccent.withValues(alpha: 0.12)
                          : AppColors.surfaceCard),
                  border: Border.all(
                    color: (isSendActive || isVoiceCallActive)
                        ? AppColors.indigoAccent
                        : AppColors.dividerColor,
                    width: 1,
                  ),
                ),
                child: IconButton(
                  onPressed: isSendActive
                      ? _handleSubmit
                      : (isVoiceCallActive ? widget.onVoiceCallTap : null),
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    isSendActive
                        ? Icons.arrow_upward_rounded
                        : (widget.onVoiceCallTap != null
                            ? Icons.phone_in_talk_rounded
                            : Icons.arrow_upward_rounded),
                    color: isSendActive
                        ? Colors.white
                        : (isVoiceCallActive
                            ? AppColors.indigoAccent
                            : AppColors.slateMuted.withValues(alpha: 0.5)),
                    size: 20.r,
                  ),
                  tooltip: isSendActive
                      ? 'Send Message'
                      : (widget.onVoiceCallTap != null ? 'Start Voice Call' : 'Send Message'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
