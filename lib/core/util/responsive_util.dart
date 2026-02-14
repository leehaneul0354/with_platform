// 목적: 화면 너비에 따른 모바일/웹 구분 유틸.
// 흐름: ResponsiveLayout·메인 화면에서 호출 → 레이아웃 분기.

import 'package:flutter/material.dart';
import '../constants/responsive_breakpoints.dart';

/// 반응형 판별 및 레이아웃 분기용 유틸 (ResponsiveHelper)
class ResponsiveHelper {
  /// 현재 화면이 모바일(단일 컬럼)인지
  static bool isMobile(BuildContext context) {
    return MediaQuery.sizeOf(context).width <= ResponsiveBreakpoints.mobileMax;
  }

  /// 데스크톱/태블릿(2컬럼 등)인지
  static bool isDesktop(BuildContext context) {
    return MediaQuery.sizeOf(context).width > ResponsiveBreakpoints.mobileMax;
  }

  /// 화면 너비 반환 (레이아웃 계산용)
  static double screenWidth(BuildContext context) {
    return MediaQuery.sizeOf(context).width;
  }
}
