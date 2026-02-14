// 목적: WITH 플랫폼 전역 색상 상수 정의.
// 흐름: ThemeData 및 위젯에서 참조 → UI 일관성 유지.

import 'package:flutter/material.dart';

/// WITH 브랜드 메인 컬러 및 UI 색상
abstract class AppColors {
  /// 노란색 (헤더, 강조) — #FFD700
  static const Color yellow = Color(0xFFFFD700);

  /// 산호/분홍 (카드, CTA 버튼) — #FF7F7F
  static const Color coral = Color(0xFFFF7F7F);

  /// 흰색 (텍스트 on 산호/노랑)
  static const Color white = Colors.white;

  /// 어두운 회색 (제목, 본문)
  static const Color textPrimary = Color(0xFF333333);

  /// 연한 회색 (부가 문구)
  static const Color textSecondary = Color(0xFF757575);

  /// 비활성 토글/버튼 배경
  static const Color inactiveBackground = Color(0xFFE0E0E0);
}
