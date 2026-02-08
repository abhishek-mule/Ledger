import 'package:flutter/material.dart';

class AppTheme {
  // Dark background with subtle contrast - private, serious atmosphere
  static const Color backgroundDark = Color(0xFF0D0D0D);
  static const Color surfaceDark = Color(0xFF1A1A1A);
  static const Color surfaceVariantDark = Color(0xFF262626);

  // Light variant for light mode (rarely used but defined)
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

  static ThemeData get darkTheme {
    return ThemeData(
      colorScheme: const ColorScheme.dark(
        primary: primary,
        onPrimary: textOnPrimary,
        primaryContainer: primaryVariant,
        secondary: secondary,
        onSecondary: textPrimary,
        secondaryContainer: secondaryVariant,
        background: backgroundDark,
        onBackground: textPrimary,
        surface: surfaceDark,
        onSurface: textPrimary,
        surfaceVariant: surfaceVariantDark,
        onSurfaceVariant: textSecondary,
        error: error,
        onError: textOnPrimary,
      ),
      scaffoldBackgroundColor: backgroundDark,
      cardColor: surfaceDark,
      dialogBackgroundColor: surfaceDark,
      dividerColor: surfaceVariantDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundDark,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      bottomAppBarTheme: const BottomAppBarTheme(
        color: surfaceDark,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: textOnPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariantDark,
        hintStyle: const TextStyle(color: textTertiary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: gray700),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: gray700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 57,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.25,
        ),
        displayMedium: TextStyle(
          fontSize: 45,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: 0,
        ),
        displaySmall: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: 0,
        ),
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: 0,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: 0,
        ),
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: 0,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: 0,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: 0.15,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: 0.1,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          letterSpacing: 0.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          letterSpacing: 0.25,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          letterSpacing: 0.4,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: 0.1,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textSecondary,
          letterSpacing: 0.5,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textTertiary,
          letterSpacing: 0.5,
        ),
      ),
      useMaterial3: true,
    );
  }

  static ThemeData get lightTheme {
    // Light theme follows same principles but with light backgrounds
    return ThemeData(
      colorScheme: const ColorScheme.light(
        primary: primary,
        onPrimary: textOnPrimary,
        primaryContainer: primaryVariant,
        secondary: secondary,
        onSecondary: textOnPrimary,
        secondaryContainer: secondaryVariant,
        background: backgroundLight,
        onBackground: gray900,
        surface: surfaceLight,
        onSurface: gray900,
        surfaceVariant: gray100,
        onSurfaceVariant: gray700,
        error: error,
        onError: textOnPrimary,
      ),
      scaffoldBackgroundColor: backgroundLight,
      cardColor: surfaceLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundLight,
        foregroundColor: gray900,
        elevation: 0,
      ),
      useMaterial3: true,
    );
  }
}
