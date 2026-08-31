import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

class VoiceControlBar extends StatelessWidget {
  final bool isMuted;
  final String localeId;
  final bool showSubtitles;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleLanguage;
  final VoidCallback onToggleSubtitles;
  final VoidCallback onEndCall;

  const VoiceControlBar({
    super.key,
    required this.isMuted,
    required this.localeId,
    required this.showSubtitles,
    required this.onToggleMute,
    required this.onToggleLanguage,
    required this.onToggleSubtitles,
    required this.onEndCall,
  });

  @override
  Widget build(BuildContext context) {
    final bool isIndonesian = localeId == 'id_ID';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg.w,
        vertical: AppSpacing.md.h,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mute Button
          _VoiceActionButton(
            buttonKey: const Key('voice_control_mute_button'),
            semanticLabel: isMuted ? 'Unmute microphone' : 'Mute microphone',
            tooltip: isMuted ? 'Unmute microphone' : 'Mute microphone',
            onTap: onToggleMute,
            backgroundColor: isMuted
                ? AppColors.statusError.withValues(alpha: 0.22)
                : AppColors.surfaceCard.withValues(alpha: 0.15),
            borderColor: isMuted
                ? AppColors.statusError.withValues(alpha: 0.5)
                : AppColors.dividerColor.withValues(alpha: 0.25),
            child: Icon(
              isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
              color: isMuted ? AppColors.statusError : AppColors.userText,
              size: 24.r,
            ),
          ),

          // Language Switch Button
          _VoiceActionButton(
            buttonKey: const Key('voice_control_language_button'),
            semanticLabel: isIndonesian
                ? 'Switch language to English'
                : 'Switch language to Indonesian',
            tooltip: isIndonesian ? 'Switch to English' : 'Switch to Indonesian',
            onTap: onToggleLanguage,
            backgroundColor: isIndonesian
                ? AppColors.micActive.withValues(alpha: 0.22)
                : AppColors.surfaceCard.withValues(alpha: 0.15),
            borderColor: isIndonesian
                ? AppColors.micActive.withValues(alpha: 0.5)
                : AppColors.dividerColor.withValues(alpha: 0.25),
            child: Text(
              isIndonesian ? 'ID' : 'EN',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: isIndonesian ? AppColors.micActive : AppColors.userText,
                letterSpacing: 0.5,
              ),
            ),
          ),

          // Subtitles Toggle Button
          _VoiceActionButton(
            buttonKey: const Key('voice_control_subtitles_button'),
            semanticLabel: showSubtitles ? 'Hide subtitles' : 'Show subtitles',
            tooltip: showSubtitles ? 'Hide subtitles' : 'Show subtitles',
            onTap: onToggleSubtitles,
            backgroundColor: showSubtitles
                ? AppColors.indigoAccentLight.withValues(alpha: 0.22)
                : AppColors.surfaceCard.withValues(alpha: 0.08),
            borderColor: showSubtitles
                ? AppColors.indigoAccentLight.withValues(alpha: 0.45)
                : AppColors.dividerColor.withValues(alpha: 0.15),
            child: Icon(
              showSubtitles ? Icons.subtitles_rounded : Icons.subtitles_off_rounded,
              color: showSubtitles ? AppColors.userText : AppColors.slateMuted,
              size: 24.r,
            ),
          ),

          // End Call Button
          _VoiceActionButton(
            buttonKey: const Key('voice_control_end_call_button'),
            semanticLabel: 'End voice call',
            tooltip: 'End voice call',
            onTap: onEndCall,
            size: 58.r,
            backgroundColor: AppColors.statusError,
            borderColor: AppColors.errorBorder.withValues(alpha: 0.4),
            child: Icon(
              Icons.call_end_rounded,
              color: Colors.white,
              size: 26.r,
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceActionButton extends StatelessWidget {
  final Key buttonKey;
  final String semanticLabel;
  final String tooltip;
  final VoidCallback onTap;
  final Widget child;
  final Color backgroundColor;
  final Color borderColor;
  final double? size;

  const _VoiceActionButton({
    required this.buttonKey,
    required this.semanticLabel,
    required this.tooltip,
    required this.onTap,
    required this.child,
    required this.backgroundColor,
    required this.borderColor,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final dimension = size ?? 52.r;

    return Semantics(
      label: semanticLabel,
      button: true,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: buttonKey,
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: dimension,
              height: dimension,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: backgroundColor,
                border: Border.all(
                  color: borderColor,
                  width: 1.2,
                ),
              ),
              alignment: Alignment.center,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
