import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../state/voice_call_state.dart';

class VoiceCallHeader extends StatelessWidget {
  final VoiceCallState state;
  final VoidCallback onClose;

  const VoiceCallHeader({
    super.key,
    required this.state,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.base.w,
        vertical: AppSpacing.sm.h,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            key: const Key('voice_call_close_button'),
            tooltip: 'Close voice call',
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.parchmentBackground.withValues(alpha: 0.9),
              size: 28.r,
            ),
            onPressed: onClose,
          ),
          Column(
            children: [
              Text(
                'Snape Live Voice',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.parchmentBackground,
                  letterSpacing: -0.2,
                ),
              ),
              SizedBox(height: 2.h),
              _buildPhaseBadge(),
            ],
          ),
          SizedBox(width: 48.w),
        ],
      ),
    );
  }

  Widget _buildPhaseBadge() {
    Color badgeColor;
    String badgeText;

    if (state.errorMessage != null) {
      badgeColor = AppColors.statusError;
      badgeText = 'Error';
    } else if (state.isMuted) {
      badgeColor = AppColors.statusError;
      badgeText = 'Muted';
    } else {
      switch (state.phase) {
        case VoiceCallPhase.greeting:
          badgeColor = AppColors.indigoAccentLight;
          badgeText = 'Greeting';
          break;
        case VoiceCallPhase.listening:
          badgeColor = AppColors.micActive;
          badgeText =
              state.localeId == 'id_ID' ? 'Listening (ID)' : 'Listening (EN)';
          break;
        case VoiceCallPhase.thinking:
          badgeColor = AppColors.indigoAccent;
          badgeText = 'Thinking';
          break;
        case VoiceCallPhase.speaking:
          badgeColor = AppColors.indigoAccentLight;
          badgeText = 'Speaking';
          break;
        case VoiceCallPhase.idle:
          badgeColor = AppColors.slateMuted;
          badgeText = 'Idle';
          break;
      }
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadii.pill.r),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.4),
          width: 1.0,
        ),
      ),
      child: Text(
        badgeText,
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w600,
          color: badgeColor,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
