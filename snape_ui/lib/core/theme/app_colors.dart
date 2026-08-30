import 'package:flutter/material.dart';

/// Editorial design tokens for Snape language companion.
/// Calm, focused palette designed for sustained reading and practice.
abstract final class AppColors {
  // Parchment Neutrals & Canvas
  static const Color parchmentBackground = Color(0xFFF9F8F5);
  static const Color surfaceWarm = Color(0xFFF3F1EC);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFEDE9E2);

  // Deep Warm Slates (Text & Structure)
  static const Color slatePrimary = Color(0xFF1E242B);
  static const Color slateSecondary = Color(0xFF4A5568);
  static const Color slateTertiary = Color(0xFF718096);
  static const Color slateMuted = Color(0xFFA0AEC0);
  static const Color dividerColor = Color(0xFFE2DFD8);

  // Subtle Indigo & Editorial Accents
  static const Color indigoAccent = Color(0xFF3B4F71);
  static const Color indigoAccentLight = Color(0xFF5B7298);
  static const Color indigoSoftBackground = Color(0xFFEAEFF8);

  // Companion & User Bubbles
  static const Color companionBubbleBg = Color(0xFFFFFFFF);
  static const Color companionBubbleBorder = Color(0xFFE4E0D6);
  static const Color companionText = Color(0xFF1A202C);

  static const Color userBubbleBg = Color(0xFF2C3E50);
  static const Color userText = Color(0xFFFFFFFF);

  // Semantic feedback
  static const Color statusOnline = Color(0xFF2E7D32);
  static const Color statusReconnecting = Color(0xFFED8936);
  static const Color statusError = Color(0xFFC53030);
  static const Color errorBackground = Color(0xFFFFF5F5);
  static const Color errorBorder = Color(0xFFFEB2B2);

  // Audio / Interaction Accents
  static const Color micActive = Color(0xFFB7791F);
  static const Color micRecording = Color(0xFFE53E3E);
  static const Color micIdle = Color(0xFF4A5568);
}
