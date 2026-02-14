// 목적: 모바일/태블릿/데스크톱 구분을 위한 너비 기준값.
// 흐름: ResponsiveHelper에서 참조 → 레이아웃 분기.

/// 반응형 레이아웃 브레이크포인트 (너비 px)
abstract class ResponsiveBreakpoints {
  /// 이하: 모바일 (단일 컬럼, 하단 네비)
  static const double mobileMax = 600;

  /// 초과: 태블릿/데스크톱 (2컬럼 등)
  static const double desktopMin = 601;
}
