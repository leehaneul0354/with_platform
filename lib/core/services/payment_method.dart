// 목적: 결제 수단 식별자. BottomSheet·recharges 저장·PG 연동 시 동일 키 사용.

/// 결제 수단 (UI 라벨 + Firestore/API용 id)
enum PaymentMethod {
  card('신용카드', 'card'),
  kakao('카카오페이', 'kakao'),
  naver('네이버페이', 'naver'),
  toss('토스', 'toss');

  const PaymentMethod(this.label, this.id);
  final String label;
  final String id;
}
