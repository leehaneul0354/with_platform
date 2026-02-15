// 목적: 테스트 편의를 위한 역할별 고정 계정. 배포 전 제거 대상.
// 흐름: AuthRepository.login()에서 우선 매칭 → 해당 역할 UserModel 반환.

// TODO: [DEV] 테스트용 계정 로직 — 실제 배포 시 이 파일 또는 로그인 분기 제거

import 'admin_account.dart';
import '../auth/user_model.dart';

/// 역할별 고정 테스트 계정 (ID / PW / 역할·닉네임)
abstract class TestAccounts {
  /// 환자 (Patient) — 후원 신청하기 이용 가능
  static const String patientId = '0000';
  static const String patientPw = '0000';
  static const String patientNickname = '테스트환자';

  /// 후원자 (Sponsor)
  static const String sponsorId = '1111';
  static const String sponsorPw = '1111';
  static const String sponsorNickname = '테스트후원자';

  /// 일반 회원 (General User) — 후원 신청 불가
  static const String generalId = '2222';
  static const String generalPw = '2222';
  static const String generalNickname = '테스트일반';

  /// 관리자 — AdminDashboard 이동 (AdminAccount와 동일)
  static String get adminId => AdminAccount.id;
  static String get adminPw => AdminAccount.password;
  static const String adminNickname = '관리자';

  /// 테스트 계정 여부 (배포 시 제거용)
  static bool isTestAccount(String id, String password) {
    return (id == patientId && password == patientPw) ||
        (id == sponsorId && password == sponsorPw) ||
        (id == generalId && password == generalPw) ||
        (id == adminId && password == adminPw);
  }

  /// 테스트 계정으로 로그인 시 반환할 UserModel (관리자 제외)
  static UserModel? resolveTestUser(String id, String password) {
    if (id == patientId && password == patientPw) {
      return UserModel(
        id: patientId,
        password: patientPw,
        nickname: patientNickname,
        email: '',
        type: UserType.patient,
        isAdmin: false,
      );
    }
    if (id == sponsorId && password == sponsorPw) {
      return UserModel(
        id: sponsorId,
        password: sponsorPw,
        nickname: sponsorNickname,
        email: '',
        type: UserType.donor,
        isAdmin: false,
      );
    }
    if (id == generalId && password == generalPw) {
      return UserModel(
        id: generalId,
        password: generalPw,
        nickname: generalNickname,
        email: '',
        type: UserType.donor,
        isAdmin: false,
      );
    }
    return null;
  }

  /// 관리자 계정 매칭 — type을 admin으로 반환해 권한 체크 통과
  static UserModel? resolveAdmin(String id, String password) {
    if (id == adminId && password == adminPw) {
      return UserModel(
        id: adminId,
        password: adminPw,
        nickname: adminNickname,
        email: '',
        type: UserType.admin,
        isAdmin: true,
      );
    }
    return null;
  }
}
