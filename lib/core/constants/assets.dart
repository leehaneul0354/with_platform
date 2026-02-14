// 목적: WITH 플랫폼 에셋 경로 상수. 마스코트·이미지 경로를 한곳에서 관리.
// 흐름: 로딩 화면, 프로필 기본 이미지, 후원 완료 축하 페이지 등에서 참조.

/// WITH 메인 마스코트 이미지 경로
///
/// 디자인 특징: 단순한 기하학적 도형(원, 사각형, 삼각형)에 감은 눈과 미소 짓는 입.
/// 색상: 파스텔 톤 노랑·분홍·하늘·연두 등 부드럽고 자극적이지 않은 색상.
/// 활용: 로딩 화면, 프로필 기본 이미지, 후원 완료 축하 페이지.
/// Flutter에서 에셋 경로는 프로젝트 루트 기준이며, pubspec의 assets: 에 등록된 경로와 일치해야 함.
/// (assets/assets/... 처럼 중복되지 않도록 'assets/images/...' 만 사용)
class WithMascots {
  /// 노란색 웃는 얼굴 (파스텔 노랑 원형)
  static const String yellowSmile = 'assets/images/mascot_p.png';

  /// 분홍색 웃는 얼굴 (파스텔 분홍 원형)
  static const String pinkSmile = 'assets/images/mascot_y.png';

  /// 연두/민트색 웃는 얼굴 (파스텔 연두 원형)
  static const String greenSmile = 'assets/images/mascot3.png';

  /// WITH 로고 + 노란 마스코트 (분홍 배경)
  static const String withLogo = 'assets/images/mascot1.png';

  /// 여러 마스코트 그룹 (노랑·분홍·하늘색 원·사각형·삼각형·초승달 등)
  static const String group = 'assets/images/mascots.jpg';
}

/// 마스코트 스타일 가이드 (UI 설계 시 유지할 기준)
///
/// - 도형: 원, 둥근 사각형, 삼각형, 초승달 등 단순 기하 도형
/// - 표정: 감은 눈(곡선 2줄) + 미소(위로 올라간 곡선)
/// - 색상: 파스텔 노랑(#FFD700 계열), 분홍(#FF7F7F·파스텔핑크), 하늘색, 연두/민트
/// - 활용처: 로딩 화면, 프로필 기본 이미지, 후원 완료 축하 페이지
