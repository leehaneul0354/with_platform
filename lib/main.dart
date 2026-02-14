// 목적: WITH 플랫폼 앱 진입점. 테마 적용 후 메인 화면으로 라우팅.
// 흐름: runApp(WithApp) → MaterialApp(theme: AppTheme) → home: MainScreen.

import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/main/main_screen.dart';

void main() {
  runApp(const WithApp());
}

/// WITH 플랫폼 루트 위젯
class WithApp extends StatelessWidget {
  const WithApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WITH - 신뢰 기반 의료 복지 플랫폼',
      theme: AppTheme.lightTheme,
      home: const MainScreen(),
    );
  }
}
