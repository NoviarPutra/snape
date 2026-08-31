import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../state/providers.dart';
import '../state/voice_call_state.dart';
import '../widgets/voice_call_header.dart';
import '../widgets/voice_control_bar.dart';
import '../widgets/voice_orb_visualizer.dart';
import '../widgets/voice_subtitle_card.dart';

class VoiceCallScreen extends ConsumerStatefulWidget {
  const VoiceCallScreen({super.key});

  static Route<void> route() {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const VoiceCallScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 1.0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: FadeTransition(
            opacity: curvedAnimation,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      fullscreenDialog: true,
    );
  }

  @override
  ConsumerState<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends ConsumerState<VoiceCallScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(voiceCallProvider.notifier).startCall(withGreeting: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(voiceCallProvider);
    final notifier = ref.read(voiceCallProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF13171C),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1C242F),
              Color(0xFF13171C),
              Color(0xFF0F1216),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Header
              VoiceCallHeader(
                state: state,
                onClose: () async {
                  await notifier.endCall();
                  if (context.mounted) {
                    Navigator.of(context).maybePop();
                  }
                },
              ),

              // Error banner if mic / speech unavailable
              if (state.errorMessage != null)
                _buildErrorBanner(state.errorMessage!, () {
                  notifier.startCall(withGreeting: false);
                }),

              // Orb Visualizer & Phase prompt
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: VoiceOrbVisualizer(
                            phase: state.phase,
                            isMuted: state.isMuted,
                            size: 190.w,
                          ),
                        ),
                        SizedBox(height: AppSpacing.md.h),
                        _buildPhasePrompt(state),
                      ],
                    ),
                  ),
                ),
              ),

              // Subtitles Card
              VoiceSubtitleCard(
                userSpeech: state.userSpeech,
                assistantSpeech: state.assistantSpeech,
                phase: state.phase,
                isVisible: state.showSubtitles,
                onToggleVisibility: notifier.toggleSubtitles,
              ),

              SizedBox(height: AppSpacing.sm.h),

              // Bottom Voice Controls
              VoiceControlBar(
                isMuted: state.isMuted,
                localeId: state.localeId,
                showSubtitles: state.showSubtitles,
                onToggleMute: notifier.toggleMute,
                onToggleLanguage: notifier.toggleLanguage,
                onToggleSubtitles: notifier.toggleSubtitles,
                onEndCall: () async {
                  await notifier.endCall();
                  if (context.mounted) {
                    Navigator.of(context).maybePop();
                  }
                },
              ),
              SizedBox(height: AppSpacing.xs.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhasePrompt(VoiceCallState state) {
    String text;
    if (state.isMuted) {
      text = 'Microphone muted';
    } else {
      switch (state.phase) {
        case VoiceCallPhase.greeting:
          text = 'Snape is greeting you...';
          break;
        case VoiceCallPhase.listening:
          text = state.localeId == 'id_ID'
              ? 'Listening in Indonesian (Bilingual Bridge)...'
              : 'Listening to you...';
          break;
        case VoiceCallPhase.thinking:
          text = 'Thinking...';
          break;
        case VoiceCallPhase.speaking:
          text = 'Snape is speaking...';
          break;
        case VoiceCallPhase.idle:
          text = 'Call ended';
          break;
      }
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Text(
        text,
        key: ValueKey<String>(text),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
          color: AppColors.parchmentBackground.withValues(alpha: 0.8),
          letterSpacing: -0.1,
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message, VoidCallback onRetry) {
    return Container(
      key: const Key('voice_call_error_banner'),
      margin: EdgeInsets.symmetric(
        horizontal: AppSpacing.base.w,
        vertical: AppSpacing.xs.h,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md.w,
        vertical: AppSpacing.sm.h,
      ),
      decoration: BoxDecoration(
        color: AppColors.statusError.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadii.md.r),
        border: Border.all(
          color: AppColors.statusError.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: AppColors.statusError,
            size: 20.r,
          ),
          SizedBox(width: AppSpacing.sm.w),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.sp,
                color: AppColors.errorBorder,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Retry',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.parchmentBackground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
