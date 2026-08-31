import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_colors.dart';
import '../state/voice_call_state.dart';

class VoiceOrbVisualizer extends StatefulWidget {
  final VoiceCallPhase phase;
  final double? size;
  final bool isMuted;

  const VoiceOrbVisualizer({
    super.key,
    required this.phase,
    this.size,
    this.isMuted = false,
  });

  @override
  State<VoiceOrbVisualizer> createState() => _VoiceOrbVisualizerState();
}

class _VoiceOrbVisualizerState extends State<VoiceOrbVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double dimension = widget.size ?? 220.w;

    return Semantics(
      label: 'Voice orb visualizer: ${widget.phase.name}',
      child: Container(
        key: const Key('voice_orb_visualizer'),
        width: dimension,
        height: dimension,
        alignment: Alignment.center,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              size: Size(dimension, dimension),
              painter: _VoiceOrbPainter(
                animationValue: _controller.value,
                phase: widget.phase,
                isMuted: widget.isMuted,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _VoiceOrbPainter extends CustomPainter {
  final double animationValue;
  final VoiceCallPhase phase;
  final bool isMuted;

  _VoiceOrbPainter({
    required this.animationValue,
    required this.phase,
    required this.isMuted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2;
    final baseCoreRadius = maxRadius * 0.45;

    _drawOuterEffects(canvas, center, maxRadius, baseCoreRadius);
    _drawCoreOrb(canvas, center, baseCoreRadius);
  }

  void _drawOuterEffects(
    Canvas canvas,
    Offset center,
    double maxRadius,
    double baseCoreRadius,
  ) {
    if (isMuted) {
      final paint = Paint()
        ..color = AppColors.slateMuted.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(center, baseCoreRadius * 1.15, paint);
      return;
    }

    switch (phase) {
      case VoiceCallPhase.listening:
        final pulseProgress = (math.sin(animationValue * 2 * math.pi) + 1) / 2;
        for (int i = 1; i <= 2; i++) {
          final ringRadius = baseCoreRadius +
              (maxRadius - baseCoreRadius) * (0.35 * i + 0.25 * pulseProgress);
          final ringOpacity = (0.25 - 0.08 * i + 0.15 * pulseProgress).clamp(0.0, 0.4);

          final ringPaint = Paint()
            ..color = AppColors.micActive.withValues(alpha: ringOpacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5 + (pulseProgress * 1.5);
          canvas.drawCircle(center, ringRadius, ringPaint);
        }
        break;

      case VoiceCallPhase.speaking:
        for (int i = 0; i < 3; i++) {
          final ringProgress = (animationValue + (i * 0.33)) % 1.0;
          final ringRadius = baseCoreRadius +
              (maxRadius - baseCoreRadius) * ringProgress;
          final ringOpacity = ((1.0 - ringProgress) * 0.45).clamp(0.0, 0.5);

          final wavePaint = Paint()
            ..color = AppColors.indigoAccentLight.withValues(alpha: ringOpacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = (3.0 * (1.0 - ringProgress * 0.5)).clamp(1.0, 3.0);
          canvas.drawCircle(center, ringRadius, wavePaint);
        }
        break;

      case VoiceCallPhase.thinking:
        final angle = animationValue * 2 * math.pi;
        final orbitRadius = baseCoreRadius * 1.35;
        final arcPaint = Paint()
          ..color = AppColors.indigoAccent.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 3.0;

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: orbitRadius),
          angle,
          math.pi * 0.7,
          false,
          arcPaint,
        );
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: orbitRadius),
          angle + math.pi,
          math.pi * 0.7,
          false,
          arcPaint,
        );

        final dotAngle = -angle * 1.5;
        final dotOffset = Offset(
          center.dx + (orbitRadius * 1.2) * math.cos(dotAngle),
          center.dy + (orbitRadius * 1.2) * math.sin(dotAngle),
        );
        final dotPaint = Paint()
          ..color = AppColors.indigoAccentLight.withValues(alpha: 0.7)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(dotOffset, 4.0, dotPaint);
        break;

      case VoiceCallPhase.greeting:
        final greetProgress = (animationValue * 1.5) % 1.0;
        final ringRadius = baseCoreRadius +
            (maxRadius - baseCoreRadius) * greetProgress;
        final ringOpacity = ((1.0 - greetProgress) * 0.35).clamp(0.0, 0.35);

        final greetPaint = Paint()
          ..color = AppColors.indigoSoftBackground.withValues(alpha: ringOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawCircle(center, ringRadius, greetPaint);
        break;

      case VoiceCallPhase.idle:
        final ambientProgress = (math.sin(animationValue * math.pi) + 1) / 2;
        final idlePaint = Paint()
          ..color = AppColors.slateMuted.withValues(alpha: 0.12 + 0.08 * ambientProgress)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawCircle(center, baseCoreRadius * 1.2, idlePaint);
        break;
    }
  }

  void _drawCoreOrb(Canvas canvas, Offset center, double baseCoreRadius) {
    Color startColor;
    Color endColor;

    if (isMuted) {
      startColor = AppColors.slateSecondary;
      endColor = AppColors.slatePrimary;
    } else {
      switch (phase) {
        case VoiceCallPhase.listening:
          startColor = AppColors.micActive;
          endColor = AppColors.userBubbleBg;
          break;
        case VoiceCallPhase.thinking:
          startColor = AppColors.indigoAccentLight;
          endColor = AppColors.indigoAccent;
          break;
        case VoiceCallPhase.speaking:
          startColor = AppColors.indigoAccentLight;
          endColor = AppColors.userBubbleBg;
          break;
        case VoiceCallPhase.greeting:
          startColor = AppColors.indigoAccent;
          endColor = AppColors.userBubbleBg;
          break;
        case VoiceCallPhase.idle:
          startColor = AppColors.slateSecondary;
          endColor = AppColors.slatePrimary;
          break;
      }
    }

    final double pulseScale = (phase == VoiceCallPhase.listening || phase == VoiceCallPhase.speaking)
        ? 1.0 + (0.05 * math.sin(animationValue * 2 * math.pi))
        : 1.0;
    final currentCoreRadius = baseCoreRadius * pulseScale;

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          startColor.withValues(alpha: 0.35),
          startColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: currentCoreRadius * 1.4));
    canvas.drawCircle(center, currentCoreRadius * 1.4, glowPaint);

    final corePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.25, -0.3),
        radius: 0.9,
        colors: [
          startColor,
          endColor,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: currentCoreRadius));
    canvas.drawCircle(center, currentCoreRadius, corePaint);

    final innerHighlightPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.35),
        radius: 0.4,
        colors: [
          Colors.white.withValues(alpha: 0.4),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: currentCoreRadius * 0.7));
    canvas.drawCircle(center, currentCoreRadius * 0.7, innerHighlightPaint);
  }

  @override
  bool shouldRepaint(covariant _VoiceOrbPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.phase != phase ||
        oldDelegate.isMuted != isMuted;
  }
}
