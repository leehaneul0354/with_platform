import '../constants/firestore_keys.dart';

/// 보고서 4.1항의 역할 기반 권한 체계를 위한 열거형. Firestore에는 role/type 필드로 문자열(name) 저장.
enum UserType { viewer, donor, patient, admin }

/// 역할 표시용 라벨 (한국어)
extension UserTypeLabel on UserType {
  String get label {
    switch (this) {
      case UserType.viewer:
        return '일반 회원';
      case UserType.donor:
        return '후원자';
      case UserType.patient:
        return '환자';
      case UserType.admin:
        return '관리자';
    }
  }
}

/// 회원 인증/상태 (관리자 화면용)
enum UserStatus { pending, verified }

extension UserStatusLabel on UserStatus {
  String get label {
    switch (this) {
      case UserStatus.pending:
        return '인증 대기';
      case UserStatus.verified:
        return '인증 완료';
    }
  }
}

class UserModel {
  final String id;
  /// 이메일은 선택 항목(미수집). 회원가입/로그인 UI에서는 사용하지 않음.
  final String email;
  final String password;
  final String nickname;
  final UserType type;
  final int trustScore;
  final String? joinedAt;
  final bool isVerified;
  final UserStatus status;
  /// 생년월일 YYMMDD (예: 030504). 비밀번호 찾기·회원가입 필수.
  final String? birthDate;
  /// 프로필 이미지 파일명 (예: 'profile_yellow.png' 또는 'mascot_pink.png')
  final String? profileImage;

  UserModel({
    required this.id,
    this.email = '',
    required this.password,
    required this.nickname,
    required this.type,
    this.trustScore = 0,
    this.joinedAt,
    bool? isAdmin,
    this.isVerified = false,
    UserStatus? status,
    this.birthDate,
    this.profileImage,
  }) : status = status ?? (isVerified ? UserStatus.verified : UserStatus.pending);

  /// 관리자 여부 (type == admin 과 동일, 호환용)
  bool get isAdmin => type == UserType.admin;

  /// Firestore/SharedPreferences 문서를 UserModel로 변환.
  /// 모든 필드에 대해 null/타입 안전 처리(as String? ?? '' 등)로 null 에러 원천 차단.
  factory UserModel.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return UserModel(
        id: '',
        password: '',
        nickname: '이름없음',
        type: UserType.viewer,
      );
    }
    final id = _readString(json, FirestoreUserKeys.userId) ?? _readString(json, FirestoreUserKeys.id) ?? '';
    final email = _readString(json, FirestoreUserKeys.email) ?? '';
    final password = _readString(json, FirestoreUserKeys.password) ?? '';
    final nickname = _readString(json, FirestoreUserKeys.nickname) ?? _readString(json, FirestoreUserKeys.name) ?? '이름없음';
    final type = _parseUserTypeSafe(json[FirestoreUserKeys.role] ?? json[FirestoreUserKeys.type]);
    final trustScore = (json[FirestoreUserKeys.trustScore] is int)
        ? json[FirestoreUserKeys.trustScore] as int
        : (int.tryParse(json[FirestoreUserKeys.trustScore]?.toString() ?? '0') ?? 0);
    final joinedAt = _readString(json, FirestoreUserKeys.joinedAt) ?? json[FirestoreUserKeys.createdAt]?.toString() ?? '';
    final verified = json[FirestoreUserKeys.isVerified] == true;
    final birthDate = _readBirthDate(json) ?? '';
    String? profileImage = _readString(json, FirestoreUserKeys.profileImage);
    
    // profileImage 정규화: with_mascot.png 제거 및 빈 값 처리
    if (profileImage != null && profileImage.isNotEmpty) {
      // with_mascot.png 같은 존재하지 않는 파일명을 기본값으로 교체
      if (profileImage.contains('with_mascot.png')) {
        profileImage = 'profile_yellow.png';
      } else {
        // 중복 경로 제거 및 파일명만 추출
        profileImage = profileImage
            .replaceAll('assets/assets/', '')
            .replaceAll('assets/images/', '')
            .trim();
        
        // 처리 후 빈 문자열이면 null로 설정
        if (profileImage.isEmpty) {
          profileImage = null;
        }
      }
    }
    
    // 최종적으로 null이거나 비어있으면 기본값 할당
    profileImage = profileImage?.isEmpty == true ? null : profileImage;

    return UserModel(
      id: id,
      email: email,
      password: password,
      nickname: nickname,
      type: type,
      trustScore: trustScore,
      joinedAt: joinedAt.isEmpty ? null : joinedAt,
      isVerified: verified,
      status: verified ? UserStatus.verified : UserStatus.pending,
      birthDate: birthDate.isEmpty ? null : birthDate,
      profileImage: profileImage,
    );
  }

  /// Firestore/JSON에서 문자열 안전 읽기. null/다른 타입이어도 예외 없이 String? 또는 '' 처리.
  static String? _readString(Map<String, dynamic> json, String key) {
    try {
      final v = json[key];
      if (v == null) return null;
      if (v is String) return v;
      return v.toString();
    } catch (_) {
      return null;
    }
  }

  /// birthDate: 파이어베이스 콘솔 필드명 birthDate 또는 birthdate 둘 다 지원. 없으면 ''.
  static String? _readBirthDate(Map<String, dynamic> json) {
    try {
      final v = json[FirestoreUserKeys.birthDate] ?? json[FirestoreUserKeys.birthdate];
      if (v == null) return null;
      if (v is String) return v.isEmpty ? null : v;
      if (v is int) {
        final s = v.toString();
        return s.length <= 6 ? s.padLeft(6, '0') : s;
      }
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    } catch (_) {
      return null;
    }
  }

  /// role/type 파싱 실패 시 viewer 반환으로 예외 방지 (기존 유저는 viewer로 취급)
  static UserType _parseUserTypeSafe(dynamic role) {
    try {
      if (role == null) return UserType.viewer;
      final s = role.toString().toLowerCase();
      if (s == 'admin') return UserType.admin;
      if (s == 'patient') return UserType.patient;
      if (s == 'donor') return UserType.donor;
      return UserType.viewer;
    } catch (_) {
      return UserType.viewer;
    }
  }

  /// Firestore 저장 시 FirestoreUserKeys 사용. null 필드는 '' 처리.
  Map<String, dynamic> toJson() {
    // profileImage 정규화: with_mascot.png 제거 및 파일명만 저장
    String? normalizedProfileImage = profileImage;
    
    if (normalizedProfileImage != null && normalizedProfileImage.isNotEmpty) {
      // with_mascot.png 같은 존재하지 않는 파일명 제거
      if (normalizedProfileImage.contains('with_mascot.png')) {
        normalizedProfileImage = 'profile_yellow.png';
      } else {
        // 중복 경로 제거 및 파일명만 추출
        normalizedProfileImage = normalizedProfileImage
            .replaceAll('assets/assets/', '')
            .replaceAll('assets/images/', '')
            .trim();
        
        // 처리 후 빈 문자열이면 기본값 할당
        if (normalizedProfileImage.isEmpty) {
          normalizedProfileImage = 'profile_yellow.png';
        }
      }
    } else {
      // null이거나 비어있으면 기본값 할당
      normalizedProfileImage = 'profile_yellow.png';
    }
    
    return {
      FirestoreUserKeys.userId: id,
      FirestoreUserKeys.id: id,
      FirestoreUserKeys.email: email,
      FirestoreUserKeys.password: password,
      FirestoreUserKeys.nickname: nickname,
      FirestoreUserKeys.role: type.name,
      FirestoreUserKeys.type: type.name,
      FirestoreUserKeys.trustScore: trustScore,
      FirestoreUserKeys.joinedAt: joinedAt,
      FirestoreUserKeys.birthDate: birthDate ?? '',
      FirestoreUserKeys.profileImage: normalizedProfileImage,
    };
  }

  UserModel copyWith({
    String? nickname,
    String? email,
    String? joinedAt,
    int? trustScore,
    bool? isVerified,
    UserStatus? status,
    String? password,
    String? birthDate,
    String? profileImage,
  }) {
    final newVerified = isVerified ?? this.isVerified;
    final newStatus = status ?? (isVerified != null ? (isVerified ? UserStatus.verified : UserStatus.pending) : this.status);
    return UserModel(
      id: id,
      email: email ?? this.email,
      password: password ?? this.password,
      nickname: nickname ?? this.nickname,
      type: type,
      trustScore: trustScore ?? this.trustScore,
      joinedAt: joinedAt ?? this.joinedAt,
      isVerified: newVerified,
      status: newStatus,
      birthDate: birthDate ?? this.birthDate,
      profileImage: profileImage ?? this.profileImage,
    );
  }
}