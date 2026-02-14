// 목적: WITH 플랫폼 전역 ThemeData (노란/산호 메인 컬러 반영).
// 흐름: main → MaterialApp theme → 전체 위젯.

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// WITH 앱 테마 데이터
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.coral,
        primary: AppColors.coral,
        secondary: AppColors.yellow,
        surface: Colors.white,
        onPrimary: AppColors.white,
        onSecondary: AppColors.textPrimary,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.yellow,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.coral,
          foregroundColor: AppColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
    );
  }
}
