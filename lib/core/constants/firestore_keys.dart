// 목적: Firestore 컬렉션·문서 필드명을 상수로 관리. UserModel·AuthRepository 등에서 문자열 키 대신 사용.

/// Firestore 컬렉션 이름
class FirestoreCollections {
  FirestoreCollections._();

  static const String users = 'users';
  static const String posts = 'posts';
  static const String platformStats = 'platform_stats';
  static const String donations = 'donations';
  static const String recharges = 'recharges';
  static const String thankYouPosts = 'thank_you_posts';
  static const String todayThankYou = 'today_thank_you';
  static const String comments = 'comments';
  static const String likes = 'likes';
}

/// recharges 문서 필드 (충전 내역)
class RechargeKeys {
  RechargeKeys._();

  static const String userId = 'userId';
  static const String amount = 'amount';
  static const String paymentMethod = 'paymentMethod';
  static const String createdAt = 'createdAt';
}

/// donations 문서 필드 (후원 내역)
class DonationKeys {
  DonationKeys._();

  static const String userId = 'userId';
  static const String amount = 'amount';
  static const String postTitle = 'postTitle';
  static const String postId = 'postId';
  static const String createdAt = 'createdAt';
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
  /// 목표 달성 시 자동 설정
  static const String completed = 'completed';
  /// 게시물별 누적 모금액 (후원 시 increment, 기본 0)
  static const String currentAmount = 'currentAmount';
  /// 게시물별 목표 모금액 (후원금 유형 시)
  static const String goalAmount = 'goalAmount';
  /// 후원 유형: 'money'(후원금) | 'goods'(후원물품)
  static const String fundingType = 'fundingType';
  static const String fundingTypeMoney = 'money';
  static const String fundingTypeGoods = 'goods';
  /// 필요 물품 리스트 (후원물품 유형 시, 문자열)
  static const String neededItems = 'neededItems';
  /// 후원 사용 목적 (선택, 예: 치료비, 간병비, 보조기구 구입)
  static const String usagePurpose = 'usagePurpose';
  /// 게시물 유형: 'struggle'(투병 기록) | 'thanks'(감사 편지)
  static const String type = 'type';
  static const String typeStruggle = 'struggle';
  static const String typeThanks = 'thanks';
}

/// thank_you_posts 문서 필드 (감사 편지 대기/승인)
class ThankYouPostKeys {
  ThankYouPostKeys._();
  static const String title = 'title';
  static const String content = 'content';
  static const String imageUrls = 'imageUrls';
  static const String patientId = 'patientId';
  static const String patientName = 'patientName';
  static const String postId = 'postId';
  /// 연결된 게시물(투병 기록) 제목 — 관리자 리스트에서 문맥 표시용
  static const String postTitle = 'postTitle';
  static const String createdAt = 'createdAt';
  static const String status = 'status';
  static const String pending = 'pending';
  static const String approved = 'approved';
  static const String type = 'type';
  /// 사용 목적(선택) — 있다면 관리자 카드에 표시
  static const String usagePurpose = 'usagePurpose';
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

  /// WITH Pay 잔액 (int, 기본값 0)
  static const String withPayBalance = 'withPayBalance';

  /// 레거시/콘솔용 별칭 (읽기 시에만 사용)
  static const String name = 'name';
  static const String birthdate = 'birthdate';
}

/// comments 문서 필드 (댓글)
class CommentKeys {
  CommentKeys._();

  static const String content = 'content';
  static const String userId = 'userId';
  static const String userName = 'userName';
  static const String timestamp = 'timestamp';
  static const String isSponsor = 'isSponsor';
  static const String postId = 'postId';
  static const String postType = 'postType'; // 'post' 또는 'thank_you'
}

/// likes 문서 필드 (좋아요)
class LikeKeys {
  LikeKeys._();

  static const String userId = 'userId';
  static const String postId = 'postId';
  static const String postType = 'postType'; // 'post' 또는 'thank_you'
  static const String timestamp = 'timestamp';
}
