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
