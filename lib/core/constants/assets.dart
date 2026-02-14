// 목적: WITH 플랫폼 에셋 경로 상수. 마스코트·이미지 경로를 한곳에서 관리.
// 흐름: 스플래시, 로딩, 로그인, 마이페이지 등에서 참조.
// 파일명은 공백 없이 언더바(_) 사용 (예: mascot_p.png). pubspec의 assets: - assets/images/ 에 등록됨.

/// 이미지 최대 가로 비율 (UI4.jpg 스타일, 깔끔한 여백)
const double kMaxImageWidthRatio = 0.3;

/// WITH 마스코트·화면별 이미지 경로
class WithMascots {
  WithMascots._();

  /// 스플래시 중앙 이미지
  static const String splash = 'assets/images/image_48dd69.png';

  /// 로딩 시 둥둥 떠다니는 마스코트
  static const String loading = 'assets/images/mascot_p.png';

  /// 로그인 상단 마스코트 (말풍선과 함께)
  static const String login = 'assets/images/mascot1.jpg';

  /// 마이페이지 기본 프로필(원형)
  static const String profileDefault = 'assets/images/mascot_y.png';

  /// 빈 후원내역 등 시무룩한 표정 마스코트 (없으면 mascot_sad.png 추가)
  static const String sad = 'assets/images/mascot_sad.png';

  /// 노란색 웃는 얼굴 (파스텔 노랑 원형)
  static const String yellowSmile = 'assets/images/mascot_p.png';

  /// 분홍색 웃는 얼굴 (파스텔 분홍 원형)
  static const String pinkSmile = 'assets/images/mascot_y.png';

  /// 연두/민트색 웃는 얼굴
  static const String greenSmile = 'assets/images/mascot3.png';

  /// WITH 로고 + 노란 마스코트 (분홍 배경)
  static const String withLogo = 'assets/images/mascot1.png';

  /// 여러 마스코트 그룹
  static const String group = 'assets/images/mascots.jpg';
}

/// 마스코트 스타일 가이드 (UI 설계 시 유지할 기준)
///
/// - 도형: 원, 둥근 사각형, 삼각형, 초승달 등 단순 기하 도형
/// - 표정: 감은 눈(곡선 2줄) + 미소(위로 올라간 곡선)
/// - 색상: 파스텔 노랑(#FFD700 계열), 분홍(#FF7F7F·파스텔핑크), 하늘색, 연두/민트
/// - 활용처: 로딩 화면, 프로필 기본 이미지, 후원 완료 축하 페이지
