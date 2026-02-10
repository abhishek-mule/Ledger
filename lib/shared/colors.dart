import 'package:flutter/material.dart';

class AppColors {
  // ═══════════════════════════════════════════════════════════════════════════
  // PREMIUM DARK MODE - Modern, Clean, Accessible
  // ═══════════════════════════════════════════════════════════════════════════

  // Background: Deep, elegant charcoal with subtle gradient appeal
  static const Color backgroundDark = Color(0xFF0F1419);    // Near-black with blue undertone
  static const Color surfaceDark = Color(0xFF1A2332);       // Deep blue-gray
  static const Color surfaceVariantDark = Color(0xFF252E3A); // Slightly lighter variant
  static const Color surfaceElevated = Color(0xFF2A3847);   // For elevated surfaces

  // Light variant for light mode
  static const Color backgroundLight = Color(0xFFFAFBFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceLightVariant = Color(0xFFF5F7FB);

  // Modern Neutral Grays - carefully calibrated
  static const Color gray50 = Color(0xFFFAFBFC);
  static const Color gray100 = Color(0xFFF5F7FB);
  static const Color gray200 = Color(0xFFEAEEF5);
  static const Color gray300 = Color(0xFFDDE3ED);
  static const Color gray400 = Color(0xFFBCC5D8);
  static const Color gray500 = Color(0xFF8B96A8);
  static const Color gray600 = Color(0xFF6B7684);
  static const Color gray700 = Color(0xFF505B6F);
  static const Color gray800 = Color(0xFF35404F);
  static const Color gray900 = Color(0xFF1A2332);

  // Primary: Modern Vibrant Blue (Material 3 inspired)
  static const Color primary = Color(0xFF2563EB);           // Vibrant blue
  static const Color primaryVariant = Color(0xFF1D4ED8);    // Deeper blue
  static const Color primaryLight = Color(0xFF60A5FA);      // Light blue
  static const Color primaryVeryLight = Color(0xFFDBEAFE);  // Very light blue
  static const Color primaryContainer = Color(0xFF1E40AF);  // Container color

  // Secondary: Sophisticated Teal
  static const Color secondary = Color(0xFF0D9488);         // Vibrant teal
  static const Color secondaryVariant = Color(0xFF0F766E);  // Darker teal
  static const Color secondaryLight = Color(0xFF2DD4BF);    // Light teal

  // Semantic Colors
  static const Color success = Color(0xFF10B981);           // Vibrant green
  static const Color successLight = Color(0xFFA7F3D0);
  static const Color warning = Color(0xFFF59E0B);           // Warm amber
  static const Color warningLight = Color(0xFFFED7AA);
  static const Color error = Color(0xFFEF4444);             // Bright red
  static const Color errorLight = Color(0xFFFECACA);
  static const Color info = Color(0xFF3B82F6);              // Info blue

  // Text colors - enhanced contrast for accessibility
  static const Color textPrimary = Color(0xFFF1F5F9);       // Almost white
  static const Color textSecondary = Color(0xFFCBD5E1);     // Light gray
  static const Color textTertiary = Color(0xFF94A3B8);      // Medium gray
  static const Color textOnPrimary = Color(0xFFFFFFFF);     // Pure white
  static const Color textOnSecondary = Color(0xFFFFFFFF);

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
