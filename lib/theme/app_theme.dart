import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand tokens — kept identical to the HTML prototype so the native app
/// feels like the same product as the website.
class AppColors {
  static const ink = Color(0xFF12232E);
  static const inkSoft = Color(0xFF1D3444);
  static const paper = Color(0xFFF5F3EE);
  static const paperDim = Color(0xFFECE8DE);
  static const emerald = Color(0xFF1F6F5C);
  static const emeraldDark = Color(0xFF164F42);
  static const emeraldLight = Color(0xFFDCEAE5);
  static const gold = Color(0xFFC9A227);
  static const goldLight = Color(0xFFF3E6BE);
  static const coral = Color(0xFFB44B3C);
  static const muted = Color(0xFF6B7480);
  static const line = Color(0xFFE3DFD5);
  static const white = Color(0xFFFFFFFF);
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.paper,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.ink,
        secondary: AppColors.gold,
        surface: AppColors.white,
        error: AppColors.coral,
      ),
      textTheme: GoogleFonts.tajawalTextTheme(base.textTheme).copyWith(
        headlineSmall: GoogleFonts.elMessiri(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        headlineMedium: GoogleFonts.elMessiri(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.ink,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.tajawal(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: AppColors.line, width: 1.4),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: AppColors.line, width: 1.4),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: AppColors.emerald, width: 1.6),
        ),
      ),
      useMaterial3: true,
    );
  }
}
