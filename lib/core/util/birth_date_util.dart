/// 생년월일 YYMMDD ↔ YYYY-MM-DD 변환 및 화면 표시 포맷.
///
/// - Firestore에는 YYYY-MM-DD(ISO 형식)로 저장.
/// - UI에서는 "2003년 05월 04일" 형태로 표시.
/// - 1900년대/2000년대 구분: 입력 YY가 현재 연도(뒤 2자리)보다 크면 19YY, 아니면 20YY.
library;

class BirthDateUtil {
  BirthDateUtil._();

  /// 6자리 YYMMDD → YYYY-MM-DD 변환.
  ///
  /// 규칙:
  /// - YY > 현재 연도(예: 26) → 19YY (예: 60 → 1960)
  /// - YY ≤ 현재 연도 → 20YY (예: 03 → 2003)
  /// - 6자리 숫자가 아니거나, 월(01~12)·일(01~31) 범위를 벗어나면 null 반환.
  /// - 일(day)은 1~31만 검사. 2월 30일 등 비유효일은 허용(단순화). 필요 시 DateTime.tryParse로 엄격 검사 가능.
  static String? yymmddToIso(String yymmdd) {
    final s = yymmdd.trim();
    if (s.length != 6 || !RegExp(r'^\d{6}$').hasMatch(s)) return null;
    final yy = s.substring(0, 2);
    final mm = s.substring(2, 4);
    final dd = s.substring(4, 6);
    final yyNum = int.tryParse(yy);
    final month = int.tryParse(mm);
    final day = int.tryParse(dd);
    if (yyNum == null || month == null || month < 1 || month > 12 || day == null || day < 1 || day > 31) return null;
    final currentYy = DateTime.now().year % 100;
    final prefix = yyNum > currentYy ? '19' : '20';
    return '$prefix$yy-$mm-$dd';
  }

  /// Firestore에 저장된 생년월일을 화면 표시용 문자열로 변환.
  ///
  /// - YYYY-MM-DD → "YYYY년 MM월 DD일"
  /// - 레거시 6자리 YYMMDD → yymmddToIso로 변환 후 동일 형식, 변환 실패 시 원문 반환
  /// - null/빈 문자열 → "-"
  static String formatBirthDateForDisplay(String? stored) {
    if (stored == null || stored.isEmpty) return '-';
    final s = stored.trim();
    if (s.length == 10 && s[4] == '-' && s[7] == '-') {
      final y = s.substring(0, 4);
      final m = s.substring(5, 7);
      final d = s.substring(8, 10);
      return '$y년 $m월 $d일';
    }
    if (s.length == 6 && RegExp(r'^\d{6}$').hasMatch(s)) {
      final iso = yymmddToIso(s);
      if (iso != null) return formatBirthDateForDisplay(iso);
      return s;
    }
    return s;
  }

  /// 6자리 YYMMDD 입력 유효성 검사. 길이·숫자·월(1~12)·일(1~31)만 검사.
  static bool isValidYymmdd(String input) {
    final s = input.trim();
    if (s.length != 6 || !RegExp(r'^\d{6}$').hasMatch(s)) return false;
    final mm = int.tryParse(s.substring(2, 4));
    final dd = int.tryParse(s.substring(4, 6));
    return mm != null && mm >= 1 && mm <= 12 && dd != null && dd >= 1 && dd <= 31;
  }
}
