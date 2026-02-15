// 목적: Firestore 컬렉션·문서 필드명을 상수로 관리. UserModel·AuthRepository 등에서 문자열 키 대신 사용.

/// Firestore 컬렉션 이름
class FirestoreCollections {
  FirestoreCollections._();

  static const String users = 'users';
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
