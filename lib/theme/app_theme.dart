import 'package:flutter/material.dart';

class AppColors {
  // Primary
  static const Color primary = Color(0xFF1AA4EC);
  static const Color primaryHover = Color(0xFF168CCA);
  static const Color primaryLight = Color(0x1A1AA4EC);
  static const Color primaryDark = Color(0xFF0D7AB8);

  // Light theme
  static const Color bgLight = Color(0xFFF2F5F9);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color chatBgLight = Color(0xFFF5F7FA);
  static const Color bubbleSelf = Color(0xFF1AA4EC);
  static const Color bubbleOtherLight = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF202124);
  static const Color textGray = Color(0xFFAAAAAA);
  static const Color borderLight = Color(0xFFE9E9E9);
  static const Color headerBgLight = Color(0xE0FFFFFF);
  static const Color iconGray = Color(0xFF5E5E5E);

  // Dark theme — refined with deeper backgrounds, better contrast
  static const Color bgDark = Color(0xFF0A0E23);
  static const Color surfaceDark = Color(0xFF111630);
  static const Color cardDark = Color(0xFF151B3A);
  static const Color cardDarkElevated = Color(0xFF1C2348);
  static const Color chatBgDark = Color(0xFF050810);
  static const Color bubbleOtherDark = Color(0xFF1E254A);
  static const Color sidebar = Color(0xFF001529);
  static const Color headerBgDark = Color(0xE0111735);
  static const Color textPrimaryDark = Color(0xFFF0F2F5);
  static const Color textGrayDark = Color(0xFF8E95A8);
  static const Color borderDark = Color(0xFF252B44);
  static const Color iconGrayDark = Color(0xFF5A6180);
  static const Color dividerDark = Color(0xFF1F2546);

  // Shared
  static const Color online = Color(0xFF52C41A);
  static const Color badgeRed = Color(0xFFFF3B30);
  static const Color gold = Color(0xFFFAAD14);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: false,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.bgLight,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.primary,
        surface: AppColors.cardLight,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.headerBgLight,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        thickness: 0.5,
        space: 0,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.borderLight, width: 0.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        hintStyle: const TextStyle(fontSize: 14, color: AppColors.textGray),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: false,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bgDark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.primary,
        surface: AppColors.cardDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.headerBgDark,
        foregroundColor: AppColors.textPrimaryDark,
        elevation: 0,
        centerTitle: true,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerDark,
        thickness: 0.5,
        space: 0,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.borderDark, width: 0.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        hintStyle: const TextStyle(fontSize: 14, color: AppColors.textGrayDark),
      ),
    );
  }
}
