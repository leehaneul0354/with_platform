// 목적: 후원 발생 시 platform_stats 갱신 뼈대. totalDonation 등 자동 증가.
// 흐름: 후원하기 완료 시 addDonation(amount) 호출 → platform_stats 문서 업데이트.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../constants/firestore_keys.dart';

/// platform_stats 단일 문서 ID (전역 통계)
const String kPlatformStatsDocId = 'default';

final FirebaseFirestore _firestore = FirebaseFirestore.instance;

/// 문서가 없으면 totalDonation/totalSupporters/activeProjects 0으로 생성
Future<void> ensurePlatformStats() async {
  try {
    final ref = _firestore.collection(FirestoreCollections.platformStats).doc(kPlatformStatsDocId);
    final snap = await ref.get();
    if (!snap.exists) {
      debugPrint('[SYSTEM] : platform_stats 문서 없음 — 초기 문서 생성');
      await ref.set({
        PlatformStatsKeys.totalDonation: 0,
        PlatformStatsKeys.totalSupporters: 0,
        PlatformStatsKeys.activeProjects: 0,
      });
      debugPrint('[SYSTEM] : platform_stats 초기 문서 생성 완료');
    }
  } catch (e) {
    debugPrint('[SYSTEM] : ensurePlatformStats 실패 $e');
    rethrow;
  }
}

/// 후원 발생 시 호출. totalDonation에 금액 누적, totalSupporters는 선택적 증가.
/// 문서가 없으면 ensurePlatformStats 후 재시도.
Future<void> addDonation({
  required int amount,
  bool incrementSupporters = true,
}) async {
  try {
    debugPrint('[SYSTEM] : addDonation 호출 — amount=$amount, incrementSupporters=$incrementSupporters');
    await ensurePlatformStats();
    final ref = _firestore.collection(FirestoreCollections.platformStats).doc(kPlatformStatsDocId);
    final updates = <String, dynamic>{
      PlatformStatsKeys.totalDonation: FieldValue.increment(amount),
    };
    if (incrementSupporters) {
      updates[PlatformStatsKeys.totalSupporters] = FieldValue.increment(1);
    }
    await ref.update(updates);
    debugPrint('[SYSTEM] : platform_stats 갱신 완료 — totalDonation +$amount');
  } catch (e) {
    debugPrint('[SYSTEM] : addDonation 실패 $e');
    rethrow;
  }
}

/// platform_stats 문서 스트림 (실시간 표시용)
Stream<DocumentSnapshot<Map<String, dynamic>>> platformStatsStream() {
  debugPrint('[SYSTEM] : platform_stats 스트림 구독');
  return _firestore
      .collection(FirestoreCollections.platformStats)
      .doc(kPlatformStatsDocId)
      .snapshots();
}

/// 테스트용 결제 시뮬레이션. 2초 대기 후 ① donations 문서 생성 ② platform_stats increment ③ post currentAmount increment.
/// 성공 시 true, 실패 시 false.
Future<bool> processPayment({
  required String userId,
  required String postId,
  required int amount,
  required String postTitle,
}) async {
  try {
    debugPrint('[PAYMENT] : processPayment 시작 — userId=$userId, postId=$postId, amount=$amount');
    await Future<void>.delayed(const Duration(seconds: 2));
    debugPrint('[PAYMENT] : 시뮬레이션 2초 완료 — 결제 성공 처리');

    await ensurePlatformStats();

    final batch = _firestore.batch();

    final donationRef = _firestore.collection(FirestoreCollections.donations).doc();
    batch.set(donationRef, {
      DonationKeys.userId: userId,
      DonationKeys.amount: amount,
      DonationKeys.postTitle: postTitle,
      DonationKeys.postId: postId,
      DonationKeys.createdAt: FieldValue.serverTimestamp(),
    });

    final statsRef = _firestore.collection(FirestoreCollections.platformStats).doc(kPlatformStatsDocId);
    batch.update(statsRef, {
      PlatformStatsKeys.totalDonation: FieldValue.increment(amount),
      PlatformStatsKeys.totalSupporters: FieldValue.increment(1),
    });

    final postRef = _firestore.collection(FirestoreCollections.posts).doc(postId);
    batch.update(postRef, {
      FirestorePostKeys.currentAmount: FieldValue.increment(amount),
    });

    await batch.commit();
    debugPrint('[PAYMENT] : donations·platform_stats·post 업데이트 완료');
    return true;
  } catch (e, st) {
    debugPrint('[PAYMENT] : processPayment 실패 — $e');
    debugPrint('[PAYMENT] : $st');
    return false;
  }
}

/// 해당 사용자의 후원 내역 스트림 (마이페이지용)
Stream<QuerySnapshot<Map<String, dynamic>>> donationsStreamByUser(String userId) {
  debugPrint('[PAYMENT] : donations 스트림 구독 — userId=$userId');
  return _firestore
      .collection(FirestoreCollections.donations)
      .where(DonationKeys.userId, isEqualTo: userId)
      .orderBy(DonationKeys.createdAt, descending: true)
      .snapshots();
}

/// 최근 후원 내역 스트림 (투데이 베스트 후원자 집계용). 최근 N건 조회.
Stream<QuerySnapshot<Map<String, dynamic>>> recentDonationsStream({int limit = 80}) {
  return _firestore
      .collection(FirestoreCollections.donations)
      .orderBy(DonationKeys.createdAt, descending: true)
      .limit(limit)
      .snapshots();
}

/// 스냅샷에서 userId별 금액 합계 후 금액 내림차순 상위 N명 반환
List<({String userId, int totalAmount})> topDonorsFromSnapshot(
  QuerySnapshot<Object?> snapshot, {
  int topN = 5,
}) {
  final map = <String, int>{};
  for (final doc in snapshot.docs) {
    final d = doc.data() as Map<String, dynamic>?;
    if (d == null) continue;
    final uid = d[DonationKeys.userId]?.toString();
    final amount = (d[DonationKeys.amount] is int)
        ? d[DonationKeys.amount] as int
        : (d[DonationKeys.amount] is num)
            ? (d[DonationKeys.amount] as num).toInt()
            : 0;
    if (uid != null && uid.isNotEmpty) {
      map[uid] = (map[uid] ?? 0) + amount;
    }
  }
  final list = map.entries
      .map((e) => (userId: e.key, totalAmount: e.value))
      .toList()
    ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
  return list.take(topN).map((e) => (userId: e.userId, totalAmount: e.totalAmount)).toList();
}

/// WITH Pay 잔액 차감 + 후원 기록·통계·게시물 금액을 Transaction으로 일괄 처리.
/// 잔액 부족 시 false, 성공 시 true.
Future<bool> processPaymentWithWithPay({
  required String userId,
  required String postId,
  required int amount,
  required String postTitle,
}) async {
  if (amount <= 0) {
    debugPrint('[WITHPAY] : processPaymentWithWithPay — amount <= 0');
    return false;
  }
  try {
    debugPrint('[WITHPAY] : 후원 처리 시작 — userId=$userId, postId=$postId, amount=$amount');
    await ensurePlatformStats();

    final userRef = _firestore.collection(FirestoreCollections.users).doc(userId);
    final postRef = _firestore.collection(FirestoreCollections.posts).doc(postId);
    final statsRef = _firestore.collection(FirestoreCollections.platformStats).doc(kPlatformStatsDocId);
    final donationRef = _firestore.collection(FirestoreCollections.donations).doc();

    final success = await _firestore.runTransaction<bool>((tx) async {
      final userSnap = await tx.get(userRef);
      if (!userSnap.exists) {
        debugPrint('[WITHPAY] : 사용자 문서 없음');
        return false;
      }
      final current = (userSnap.data()?[FirestoreUserKeys.withPayBalance] is int)
          ? (userSnap.data()![FirestoreUserKeys.withPayBalance] as int)
          : 0;
      if (current < amount) {
        debugPrint('[WITHPAY] : 잔액 부족 — current=$current, need=$amount');
        return false;
      }
      final postSnap = await tx.get(postRef);
      final postData = postSnap.exists ? (postSnap.data() ?? {}) : {};
      final currentAmount = (postData[FirestorePostKeys.currentAmount] is int)
          ? (postData[FirestorePostKeys.currentAmount] as int)
          : 0;
      final goalAmount = (postData[FirestorePostKeys.goalAmount] is int)
          ? (postData[FirestorePostKeys.goalAmount] as int)
          : (postData[FirestorePostKeys.goalAmount] is num)
              ? (postData[FirestorePostKeys.goalAmount] as num).toInt()
              : 0;
      final newAmount = currentAmount + amount;

      tx.update(userRef, {
        FirestoreUserKeys.withPayBalance: FieldValue.increment(-amount),
      });
      tx.set(donationRef, {
        DonationKeys.userId: userId,
        DonationKeys.amount: amount,
        DonationKeys.postTitle: postTitle,
        DonationKeys.postId: postId,
        DonationKeys.createdAt: FieldValue.serverTimestamp(),
      });
      tx.update(statsRef, {
        PlatformStatsKeys.totalDonation: FieldValue.increment(amount),
        PlatformStatsKeys.totalSupporters: FieldValue.increment(1),
      });
      tx.update(postRef, {
        FirestorePostKeys.currentAmount: FieldValue.increment(amount),
      });
      if (goalAmount > 0 && newAmount >= goalAmount) {
        tx.update(postRef, { FirestorePostKeys.status: FirestorePostKeys.completed });
        debugPrint('[WITHPAY] : 목표 달성 — postId=$postId, status=completed');
      }
      debugPrint('[WITHPAY] : Transaction 내 잔액 차감·후원 기록·통계·post 반영 완료');
      return true;
    });

    if (success) {
      debugPrint('[WITHPAY] : 후원 처리 완료 — $amount 원 차감');
    }
    return success;
  } catch (e, st) {
    debugPrint('[WITHPAY] : processPaymentWithWithPay 실패 — $e');
    debugPrint('[WITHPAY] : $st');
    return false;
  }
}
