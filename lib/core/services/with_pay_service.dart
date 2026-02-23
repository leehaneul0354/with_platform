// 목적: WITH Pay 잔액 충전·조회·실시간 스트림. users 문서 withPayBalance 필드 사용.
// 흐름: 마이페이지 충전 / 후원 시 잔액 차감 전 확인용.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../constants/firestore_keys.dart';

final FirebaseFirestore _firestore = FirebaseFirestore.instance;

/// userId별 잔액 스트림 캐시 — 동일 사용자에 대해 한 번만 구독 (중복 로그/구독 방지)
final Map<String, Stream<DocumentSnapshot<Map<String, dynamic>>>> _balanceStreamCache = {};

/// 서비스 초기화 플래그 (중복 구독 방지)
bool _isInitialized = false;

/// WITH Pay 서비스 초기화 (앱 시작 시 한 번만 호출)
void initializeWithPayService() {
  if (_isInitialized) {
    debugPrint('[WITHPAY] : 서비스 이미 초기화됨 - 중복 초기화 방지');
    return;
  }
  _isInitialized = true;
  debugPrint('[WITHPAY] : 서비스 초기화 완료');
}

/// WITH Pay 스트림 캐시 클리어 (로그아웃 시 호출)
void clearWithPayStreamCache() {
  _balanceStreamCache.clear();
  _isInitialized = false; // 초기화 플래그도 리셋
  debugPrint('[WITHPAY] : 잔액 스트림 캐시 완전 삭제됨 - 초기화 플래그 리셋');
}

/// 사용자 WITH Pay 잔액 한 번 읽기 (없으면 0)
Future<int> getWithPayBalance(String userId) async {
  try {
    final doc = await _firestore.collection(FirestoreCollections.users).doc(userId).get();
    final data = doc.data();
    if (data == null) return 0;
    final v = data[FirestoreUserKeys.withPayBalance];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  } catch (e) {
    debugPrint('[WITHPAY] : getWithPayBalance 실패 — $e');
    return 0;
  }
}

/// 유효한 userId인지 검사 (null·빈값·가짜 데이터 차단)
bool isValidWithPayUserId(String? userId) {
  if (userId == null || userId.isEmpty) return false;
  final t = userId.trim();
  if (t.isEmpty) return false;
  if (t == '0' || t == '0000' || t.length < 2) return false;
  return true;
}

/// 사용자 잔액 실시간 스트림 (마이페이지·후원 화면 반영용). userId당 1회만 구독·로그.
/// 로그아웃 후에는 스트림을 반환하지 않음 (세션 부활 방지)
Stream<DocumentSnapshot<Map<String, dynamic>>> withPayBalanceStream(String userId) {
  // 서비스가 초기화되지 않았으면 빈 스트림 반환 (중복 구독 방지)
  if (!_isInitialized) {
    debugPrint('[WITHPAY] : 잔액 스트림 차단 - 서비스 미초기화');
    return const Stream.empty();
  }
  
  // userId 유효성 가드: null·빈값·가짜(0, 0000 등) 차단
  if (!isValidWithPayUserId(userId)) {
    debugPrint('[WITHPAY] : 잔액 스트림 차단 - 유효하지 않은 userId');
    return const Stream.empty();
  }
  final uid = userId.trim();
  
  // 캐시에 이미 있으면 기존 스트림 반환 (중복 구독 방지)
  if (_balanceStreamCache.containsKey(uid)) {
    debugPrint('[WITHPAY] : 잔액 스트림 캐시 사용 — userId=$uid');
    return _balanceStreamCache[uid]!;
  }
  
  // 새 스트림 생성 및 캐시에 저장
  final stream = _firestore
      .collection(FirestoreCollections.users)
      .doc(uid)
      .snapshots();
  
  _balanceStreamCache[uid] = stream;
  debugPrint('[WITHPAY] : 잔액 스트림 구독 — userId=$uid (새 구독)');
  return stream;
}

/// 스냅샷에서 잔액 추출 (없으면 0)
int balanceFromSnapshot(DocumentSnapshot<Map<String, dynamic>>? snapshot) {
  if (snapshot == null || !snapshot.exists) return 0;
  final v = snapshot.data()?[FirestoreUserKeys.withPayBalance];
  if (v is int) return v;
  if (v is num) return v.toInt();
  return 0;
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
