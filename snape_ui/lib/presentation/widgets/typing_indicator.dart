import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

class TypingIndicator extends StatefulWidget {
  final Color dotColor;
  final double dotSize;

  const TypingIndicator({
    super.key,
    this.dotColor = AppColors.slateTertiary,
    this.dotSize = 5.0,
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final double value = ((_controller.value - delay) % 1.0);
            final double scale = 0.5 + (0.5 * (1.0 - (value - 0.5).abs() * 2).clamp(0.0, 1.0));
            final double opacity = 0.4 + (0.6 * (1.0 - (value - 0.5).abs() * 2).clamp(0.0, 1.0));

            return Container(
              margin: EdgeInsets.symmetric(horizontal: AppSpacing.xxs.w),
              width: (widget.dotSize * scale).r,
              height: (widget.dotSize * scale).r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.dotColor.withAlpha((opacity * 255).round()),
              ),
            );
          }),
        );
      },
    );
  }
}
