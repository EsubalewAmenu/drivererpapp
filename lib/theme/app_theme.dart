import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF10B981); // Emerald 500
  static const Color backgroundColor = Color(0xFF0F172A); // Slate 900
  static const Color surfaceColor = Color(0xFF1E293B); // Slate 800
  static const Color textColor = Color(0xFFF8FAFC); // Slate 50
  static const Color secondaryTextColor = Color(0xFF94A3B8); // Slate 400

  static const Color lightBackgroundColor = Color(0xFFFFFFFF);
  static const Color lightSurfaceColor = Color(0xFFF1F5F9); // Slate 100
  static const Color lightTextColor = Color(0xFF0F172A); // Slate 900
  static const Color lightSecondaryTextColor = Color(0xFF64748B); // Slate 500

  static bool useGoogleFonts = true;

  static TextStyle inter({
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    Color? color,
    TextDecoration? decoration,
  }) {
    if (useGoogleFonts) {
      return GoogleFonts.inter(
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        color: color,
        decoration: decoration,
      );
    }
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      color: color,
      decoration: decoration,
    );
  }

  static TextStyle sourceCodePro({
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    Color? color,
    double? height,
  }) {
     if (useGoogleFonts) {
      return GoogleFonts.sourceCodePro(
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        color: color,
        height: height,
      );
    }
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      color: color,
      height: height,
      fontFamily: 'Monospace',
    );
  }

  static TextTheme interTextTheme(TextTheme textTheme) {
    if (useGoogleFonts) {
      return GoogleFonts.interTextTheme(textTheme);
    }
    return textTheme;
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackgroundColor,
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        surface: lightSurfaceColor,
        onSurface: lightTextColor,
      ),
      textTheme: interTextTheme(ThemeData.light().textTheme).copyWith(
        displayLarge: inter(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          color: lightTextColor,
        ),
        displayMedium: inter(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: lightTextColor,
        ),
        titleLarge: inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: lightTextColor,
        ),
        bodyLarge: inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: lightTextColor,
        ),
        bodyMedium: inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: lightSecondaryTextColor,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightSurfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 0,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: lightBackgroundColor,
        elevation: 0,
        titleTextStyle: inter(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          color: lightTextColor,
        ),
        iconTheme: const IconThemeData(color: lightTextColor),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundColor,
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        surface: surfaceColor,
        onSurface: textColor,
      ),
      textTheme: interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: inter(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          color: textColor,
        ),
        displayMedium: inter(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: textColor,
        ),
        titleLarge: inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: textColor,
        ),
        bodyLarge: inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textColor,
        ),
        bodyMedium: inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: secondaryTextColor,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24), // Large radii as requested
        ),
        elevation: 0,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        elevation: 0,
        titleTextStyle: inter(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          color: textColor,
        ),
        iconTheme: const IconThemeData(color: textColor),
      ),
    );
  }
}
