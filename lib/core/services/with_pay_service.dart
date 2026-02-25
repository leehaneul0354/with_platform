// 목적: WITH Pay 잔액 충전·조회 (Future 단발 조회). users 문서 withPayBalance 필드 사용.
// 흐름: 마이페이지 충전 / 후원 시 잔액 차감 전 확인. ca9 방지를 위해 스트림 미사용.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../constants/firestore_keys.dart';

final FirebaseFirestore _firestore = FirebaseFirestore.instance;

/// 사용자 WITH Pay 잔액 단발 조회 (Firestore .get() 사용, 스트림 없음)
Future<int> getBalance(String userId) async {
  if (userId.isEmpty || userId.trim().isEmpty) {
    debugPrint('[WITHPAY] : getBalance 차단 — userId 비어 있음');
    return 0;
  }
  try {
    final doc = await _firestore
        .collection(FirestoreCollections.users)
        .doc(userId.trim())
        .get();
    final data = doc.data();
    if (data == null) return 0;
    final v = data[FirestoreUserKeys.withPayBalance];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  } catch (e) {
    debugPrint('[WITHPAY] : getBalance 실패 — $e');
    return 0;
  }
}

/// 사용자 WITH Pay 잔액 한 번 읽기 (getBalance 별칭, 기존 호환)
Future<int> getWithPayBalance(String userId) async {
  return getBalance(userId);
}

/// 유효한 userId인지 검사 (null·빈값·가짜 데이터 차단)
bool isValidWithPayUserId(String? userId) {
  if (userId == null || userId.isEmpty) return false;
  final t = userId.trim();
  if (t.isEmpty) return false;
  if (t == '0' || t == '0000' || t.length < 2) return false;
  return true;
}

/// 충전. Transaction으로 잔액 갱신 후 recharges 컬렉션에 내역 저장.
/// [paymentMethod] 선택 시 recharges 문서에 저장 (예: card, kakao, naver, toss).
/// 반환: 성공 시 충전 후 잔액, 실패 시 null.
Future<int?> rechargeWithPay(
  String userId,
  int amount, {
  String? paymentMethod,
}) async {
  if (amount <= 0) {
    debugPrint('[WITHPAY] : rechargeWithPay — 금액 0 이하 무시');
    return null;
  }
  try {
    debugPrint('[WITHPAY] : 충전 요청 — userId=$userId, amount=$amount, method=$paymentMethod');

    final userRef = _firestore.collection(FirestoreCollections.users).doc(userId);
    int newBalance = 0;
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(userRef);
      if (!snap.exists) {
        debugPrint('[WITHPAY] : 사용자 문서 없음 — userId=$userId');
        throw StateError('user not found');
      }
      final current = (snap.data()?[FirestoreUserKeys.withPayBalance] is int)
          ? (snap.data()![FirestoreUserKeys.withPayBalance] as int)
          : 0;
      newBalance = current + amount;
      tx.update(userRef, {
        FirestoreUserKeys.withPayBalance: FieldValue.increment(amount),
      });
    });

    await _saveRechargeRecord(userId, amount, paymentMethod);
    debugPrint('[WITHPAY] : 충전 완료 — +$amount 원 반영, 잔액=$newBalance');
    return newBalance;
  } catch (e, st) {
    debugPrint('[WITHPAY] : rechargeWithPay 실패 — $e');
    debugPrint('[WITHPAY] : $st');
    return null;
  }
}

/// recharges 컬렉션에 충전 내역 저장 (언제 얼마를 충전했는지 기록)
Future<void> _saveRechargeRecord(String userId, int amount, String? paymentMethod) async {
  try {
    await _firestore.collection(FirestoreCollections.recharges).add({
      RechargeKeys.userId: userId,
      RechargeKeys.amount: amount,
      RechargeKeys.paymentMethod: paymentMethod ?? 'unknown',
      RechargeKeys.createdAt: FieldValue.serverTimestamp(),
    });
    debugPrint('[WITHPAY] : recharges 내역 저장 — amount=$amount');
  } catch (e) {
    debugPrint('[WITHPAY] : recharges 저장 실패 — $e');
  }
}
