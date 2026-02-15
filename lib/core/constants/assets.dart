// 목적: WITH 플랫폼 에셋 경로 상수. 마스코트·이미지 경로를 한곳에서 관리.
// 흐름: 스플래시, 로딩, 로그인, 마이페이지 등에서 참조.
// pubspec: images/ 사용 → Flutter 웹 빌드 시 build/web/assets/images/ 로 출력 (assets/assets/ 중복 404 방지).

/// 이미지 최대 가로 비율 (UI4.jpg 스타일, 깔끔한 여백)
const double kMaxImageWidthRatio = 0.3;

/// WITH 마스코트·화면별 이미지 경로
class WithMascots {
  WithMascots._();

  /// 스플래시 중앙 이미지
  static const String splash = 'images/mascot_yellow.png';

  /// 로딩 시 둥둥 떠다니는 마스코트
  static const String loading = 'images/mascot_yellow.png';

  /// 로그인 상단 마스코트 (말풍선과 함께)
  static const String login = 'images/mascot1.jpg';

  /// 마이페이지 기본 프로필(원형)
  static const String profileDefault = 'images/mascot_pink.png';

  /// 빈 후원내역 등 시무룩한 표정 마스코트
  static const String sad = 'images/mascot_green.png';

  /// 노란색 웃는 얼굴 (파스텔 노랑 원형)
  static const String yellowSmile = 'images/mascot_yellow.png';

  /// 분홍색 웃는 얼굴 (파스텔 분홍 원형)
  static const String pinkSmile = 'images/mascot_pink.png';

  /// 연두/민트색 웃는 얼굴
  static const String greenSmile = 'images/mascot_green.png';

  /// WITH 로고 + 노란 마스코트 (분홍 배경)
  static const String withLogo = 'images/mascot1.png';

  /// 여러 마스코트 그룹
  static const String group = 'images/mascots.jpg';

  /// 메인 카드 우측 하단 노란색 마스코트 (mascot_crescent → mascot_yellow 통일)
  static const String cardMascot = 'images/mascot_yellow.png';
}

/// 마스코트 스타일 가이드 (UI 설계 시 유지할 기준)
///
/// - 도형: 원, 둥근 사각형, 삼각형, 초승달 등 단순 기하 도형
/// - 표정: 감은 눈(곡선 2줄) + 미소(위로 올라간 곡선)
/// - 색상: 파스텔 노랑(#FFD700 계열), 분홍(#FF7F7F·파스텔핑크), 하늘색, 연두/민트
/// - 활용처: 로딩 화면, 프로필 기본 이미지, 후원 완료 축하 페이지
