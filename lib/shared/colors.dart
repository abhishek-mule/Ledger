import 'package:flutter/material.dart';

class AppColors {
  // Dark background with subtle contrast - private, serious atmosphere
  static const Color backgroundDark = Color(0xFF0D0D0D);
  static const Color surfaceDark = Color(0xFF1A1A1A);
  static const Color surfaceVariantDark = Color(0xFF262626);

  // Light variant for light mode
  static const Color backgroundLight = Color(0xFFF5F5F5);
  static const Color surfaceLight = Color(0xFFFFFFFF);

  // Neutral grays for structure
  static const Color gray50 = Color(0xFFFAFAFA);
  static const Color gray100 = Color(0xFFF5F5F5);
  static const Color gray200 = Color(0xFFEEEEEE);
  static const Color gray300 = Color(0xFFE0E0E0);
  static const Color gray400 = Color(0xFFBDBDBD);
  static const Color gray500 = Color(0xFF9E9E9E);
  static const Color gray600 = Color(0xFF757575);
  static const Color gray700 = Color(0xFF616161);
  static const Color gray800 = Color(0xFF424242);
  static const Color gray900 = Color(0xFF212121);

  // Muted blue for primary actions
  static const Color primary = Color(0xFF5B7FA6);
  static const Color primaryVariant = Color(0xFF4A6A8F);
  static const Color primaryLight = Color(0xFF7A9CC6);

  // Red only for failure indicators
  static const Color error = Color(0xFFB84848);
  static const Color errorLight = Color(0xFFD66969);

  // Secondary - muted teal for contrast
  static const Color secondary = Color(0xFF4A7A7A);
  static const Color secondaryVariant = Color(0xFF3D6666);

  // Success - muted green (used sparingly)
  static const Color success = Color(0xFF4A7A4A);
  static const Color warning = Color(0xFFB88A4A);

  // Text colors
  static const Color textPrimary = Color(0xFFE8E8E8);
  static const Color textSecondary = Color(0xFFA0A0A0);
  static const Color textTertiary = Color(0xFF707070);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Chart colors for Reality screen - monochrome with subtle variations
  static const List<Color> chartColors = [
    Color(0xFF5B7FA6), // Primary blue
    Color(0xFF7A9CC6), // Light blue
    Color(0xFF4A7A7A), // Teal
    Color(0xFF4A7A4A), // Green
    Color(0xFFB88A4A), // Orange
    Color(0xFFB84848), // Red
  ];
}
