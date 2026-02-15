// 목적: Firestore 컬렉션·문서 필드명을 상수로 관리. UserModel·AuthRepository 등에서 문자열 키 대신 사용.

/// Firestore 컬렉션 이름
class FirestoreCollections {
  FirestoreCollections._();

  static const String users = 'users';
  static const String posts = 'posts';
  static const String platformStats = 'platform_stats';
}

/// platform_stats 문서 필드 (후원 현황 등)
class PlatformStatsKeys {
  PlatformStatsKeys._();

  static const String totalDonation = 'totalDonation';
  static const String totalSupporters = 'totalSupporters';
  static const String activeProjects = 'activeProjects';
}

/// Firestore posts 문서 필드·상태값 (게시물 승인 대기 등)
class FirestorePostKeys {
  FirestorePostKeys._();

  static const String title = 'title';
  static const String content = 'content';
  static const String imageUrls = 'imageUrls';
  static const String patientId = 'patientId';
  static const String patientName = 'patientName';
  static const String createdAt = 'createdAt';
  static const String status = 'status';
  static const String pending = 'pending';
  static const String approved = 'approved';
  static const String rejected = 'rejected';
}

/// Firestore users 문서 필드 키. 코드 전반에서 이 상수만 사용할 것.
class FirestoreUserKeys {
  FirestoreUserKeys._();

  static const String userId = 'user_id';
  static const String id = 'id';
  static const String email = 'email';
  static const String password = 'password';
  static const String nickname = 'nickname';
  static const String role = 'role';
  static const String type = 'type';
  static const String trustScore = 'trust_score';
  static const String birthDate = 'birthDate';
  static const String createdAt = 'createdAt';
  static const String joinedAt = 'joinedAt';
  static const String isVerified = 'is_verified';

  /// 레거시/콘솔용 별칭 (읽기 시에만 사용)
  static const String name = 'name';
  static const String birthdate = 'birthdate';
}
