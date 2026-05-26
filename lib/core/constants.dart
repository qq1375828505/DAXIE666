import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF6B4EFF);
  static const secondary = Color(0xFF00D4AA);
  static const background = Color(0xFFF5F5F7);
  static const surface = Colors.white;
  static const error = Color(0xFFFF4757);
  static const textPrimary = Color(0xFF1A1A2E);
  static const textSecondary = Color(0xFF8E8E93);
  static const tomatoRed = Color(0xFFFF6B6B);
  static const tomatoOrange = Color(0xFFFF9F43);
}

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
        ),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: AppColors.surface,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Color(0xFF252540),
          foregroundColor: Colors.white,
        ),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: const Color(0xFF252540),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF252540),
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Color(0xFF8E8E93),
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
      );
}

class AppStrings {
  static const appName = '网文写作IDE';
  static const works = '作品';
  static const outline = '大纲';
  static const materials = '资料';
  static const aiChat = 'AI对话';
}
