import 'package:flutter/material.dart';

class AppColors {
  // Primary green from Figma (mint/teal)
  static const Color primary = Color(0xFF7ED9C8);
  static const Color primaryDark = Color(0xFF2B7A6E);
  static const Color navBackground = Color(0xFFBCECE0);
  
  // Light Mode
  static const Color backgroundLight = Color(0xFFFAFAFA);
  static const Color surfaceLight = Colors.white;
  static const Color textPrimaryLight = Color(0xFF1A1A1A);
  static const Color textSecondaryLight = Color(0xFF757575);
  static const Color textHintLight = Color(0xFFBDBDBD);
  
  // Dark Mode
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color textPrimaryDark = Color(0xFFE5E5E5);
  static const Color textSecondaryDark = Color(0xFFB0B0B0);
  static const Color textHintDark = Color(0xFF6B6B6B);
  
  // Neutral
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFEEEEEE);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey800 = Color(0xFF424242);
  static const Color grey900 = Color(0xFF212121);
  
  // Status
  static const Color error = Color(0xFFE53935);
  static const Color success = Color(0xFF43A047);
  static const Color warning = Color(0xFFFB8C00);

  // Getters dinâmicos (deprecated - usar direto do tema)
  @deprecated
  static const Color background = backgroundLight;
  @deprecated
  static const Color surface = surfaceLight;
  @deprecated
  static const Color textPrimary = textPrimaryLight;
  @deprecated
  static const Color textSecondary = textSecondaryLight;
  @deprecated
  static const Color textHint = textHintLight;
}
