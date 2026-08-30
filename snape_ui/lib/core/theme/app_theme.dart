import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.parchmentBackground,
      colorScheme: const ColorScheme.light(
        primary: AppColors.indigoAccent,
        surface: AppColors.surfaceCard,
        onSurface: AppColors.slatePrimary,
        error: AppColors.statusError,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.parchmentBackground,
        foregroundColor: AppColors.slatePrimary,
        elevation: 0,
        centerTitle: false,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerColor,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
