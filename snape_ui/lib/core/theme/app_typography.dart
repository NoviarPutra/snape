import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'app_colors.dart';

/// Clean, editorial typography system using clean serifs / refined sans for an authentic companion feel.
abstract final class AppTypography {
  static TextStyle get titleLarge => TextStyle(
        fontSize: 20.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.slatePrimary,
        letterSpacing: -0.3,
        height: 1.3,
      );

  static TextStyle get titleMedium => TextStyle(
        fontSize: 16.sp,
        fontWeight: FontWeight.w600,
        color: AppColors.slatePrimary,
        letterSpacing: -0.2,
        height: 1.35,
      );

  static TextStyle get bodyLarge => TextStyle(
        fontSize: 15.sp,
        fontWeight: FontWeight.w400,
        color: AppColors.companionText,
        letterSpacing: -0.1,
        height: 1.45,
      );

  static TextStyle get bodyMedium => TextStyle(
        fontSize: 14.sp,
        fontWeight: FontWeight.w400,
        color: AppColors.slateSecondary,
        height: 1.4,
      );

  static TextStyle get userMessage => TextStyle(
        fontSize: 15.sp,
        fontWeight: FontWeight.w400,
        color: AppColors.userText,
        letterSpacing: -0.1,
        height: 1.45,
      );

  static TextStyle get caption => TextStyle(
        fontSize: 11.sp,
        fontWeight: FontWeight.w500,
        color: AppColors.slateTertiary,
        letterSpacing: 0.1,
      );

  static TextStyle get badge => TextStyle(
        fontSize: 12.sp,
        fontWeight: FontWeight.w600,
        color: AppColors.indigoAccent,
        letterSpacing: 0.2,
      );

  static TextStyle get input => TextStyle(
        fontSize: 15.sp,
        fontWeight: FontWeight.w400,
        color: AppColors.slatePrimary,
        letterSpacing: -0.1,
      );
}
