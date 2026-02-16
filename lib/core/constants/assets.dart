// 목적: WITH 플랫폼 에셋 경로 상수. 마스코트·이미지 경로를 한곳에서 관리.
// 흐름: 스플래시, 로딩, 로그인, 마이페이지 등에서 참조.
// 경로 형식: assets/images/파일명 (선행 슬래시 없음). pubspec.yaml의 assets: - assets/images/ 와 일치.

/// 이미지 최대 가로 비율 (UI4.jpg 스타일, 깔끔한 여백)
const double kMaxImageWidthRatio = 0.3;

/// WITH 마스코트·화면별 이미지 경로 (대소문자·확장자 실제 파일명과 일치 필수)
class WithMascots {
  WithMascots._();

  /// 스플래시 중앙 이미지
  static const String splash = 'assets/images/mascot_yellow.png';

  /// 로딩 시 둥둥 떠다니는 마스코트
  static const String loading = 'assets/images/mascot_yellow.png';

  /// 로그인 상단 마스코트 (말풍선과 함께)
  static const String login = 'assets/images/mascot1.jpg';

  /// 마이페이지 기본 프로필(원형)
  static const String profileDefault = 'assets/images/mascot_pink.png';

  /// 빈 후원내역 등 시무룩한 표정 마스코트
  static const String sad = 'assets/images/mascot_green.png';

  /// 노란색 웃는 얼굴 (파스텔 노랑 원형)
  static const String yellowSmile = 'assets/images/mascot_yellow.png';

  /// 분홍색 웃는 얼굴 (파스텔 분홍 원형)
  static const String pinkSmile = 'assets/images/mascot_pink.png';

  /// 연두/민트색 웃는 얼굴
  static const String greenSmile = 'assets/images/mascot_green.png';

  /// WITH 로고 + 노란 마스코트 (분홍 배경)
  static const String withLogo = 'assets/images/mascot1.png';

  /// 여러 마스코트 그룹
  static const String group = 'assets/images/mascots.jpg';

  /// 메인 카드 우측 하단 노란색 마스코트
  static const String cardMascot = 'assets/images/mascot_yellow.png';

  /// WITH 메인 마스코트 (브랜드 자산) - 기본 마스코트
  static const String withMascot = 'assets/images/mascot_yellow.png';

  /// 기본 플레이스홀더 이미지 (에러 시 사용)
  static const String defaultPlaceholder = 'assets/images/default_placeholder.png';
}

/// 사용자 프로필 마스코트 선택 목록
class AppAssets {
  AppAssets._();

  /// 프로필 마스코트 리스트 (6종)
  static const List<String> profileMascots = [
    'assets/images/profile_yellow.png',
    'assets/images/profile_red.png',
    'assets/images/profile_blue.png',
    'assets/images/mascot_yellow.png',
    'assets/images/mascot_pink.png',
    'assets/images/mascot_green.png',
  ];

  /// 기본 프로필 이미지 (profileImage가 없을 때 사용)
  static const String defaultProfile = 'assets/images/profile_yellow.png';

  /// 프로필 이미지 파일명만 반환 (Firestore 저장용)
  static String getFileName(String fullPath) {
    return fullPath.replaceFirst('assets/images/', '');
  }

  /// 파일명을 전체 경로로 변환 (중복 경로 방지)
  static String getFullPath(String fileName) {
    if (fileName.isEmpty) {
      return defaultProfile;
    }
    String normalized = fileName.trim();
    
    // with_mascot.png 같은 존재하지 않는 파일명을 기본값으로 교체
    if (normalized.contains('with_mascot.png')) {
      normalized = getFileName(defaultProfile);
    }
    
    // 중복 경로 제거 (assets/assets/ → assets/)
    while (normalized.contains('assets/assets/')) {
      normalized = normalized.replaceFirst('assets/assets/', 'assets/');
    }
    
    // 이미 전체 경로인 경우 그대로 반환
    if (normalized.startsWith('assets/images/')) {
      return normalized;
    }
    
    // assets/로 시작하지만 images/가 없는 경우 (잘못된 형식) 정리
    if (normalized.startsWith('assets/') && !normalized.startsWith('assets/images/')) {
      return normalized.replaceFirst('assets/', 'assets/images/');
    }
    
    // 파일명만 있는 경우 경로 추가
    return 'assets/images/$normalized';
  }
}

/// 마스코트 스타일 가이드 (UI 설계 시 유지할 기준)
///
/// - 도형: 원, 둥근 사각형, 삼각형, 초승달 등 단순 기하 도형
/// - 표정: 감은 눈(곡선 2줄) + 미소(위로 올라간 곡선)
/// - 색상: 파스텔 노랑(#FFD700 계열), 분홍(#FF7F7F·파스텔핑크), 하늘색, 연두/민트
/// - 활용처: 로딩 화면, 프로필 기본 이미지, 후원 완료 축하 페이지
