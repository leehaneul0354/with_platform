// 목적: 닉네임 변경 시 플랫폼 전역 데이터 일관성 유지. Denormalization된 닉네임을 일괄 업데이트.
// 흐름: AuthRepository.updateUser(닉네임 변경) → syncNicknameAcrossCollections(userId, newNickname) → posts/thank_you_posts/today_thank_you/comments 일괄 갱신.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../constants/firestore_keys.dart';

final FirebaseFirestore _firestore = FirebaseFirestore.instance;

/// Firestore WriteBatch 최대 연산 수
const int _kBatchLimit = 500;

/// 닉네임 변경 시 해당 userId가 작성자/작성자명으로 저장된 모든 문서의 닉네임 필드를 새 값으로 일괄 업데이트.
/// 대상: posts(patientName), thank_you_posts(patientName), today_thank_you(patientName), comments(userName).
Future<void> syncNicknameAcrossCollections(String userId, String newNickname) async {
  if (userId.isEmpty || newNickname.isEmpty) return;
  try {
    debugPrint('[NICKNAME_SYNC] : 시작 — userId=$userId, newNickname=$newNickname');

    final futures = [
      _firestore
          .collection(FirestoreCollections.posts)
          .where(FirestorePostKeys.patientId, isEqualTo: userId)
          .get(),
      _firestore
          .collection(FirestoreCollections.thankYouPosts)
          .where(ThankYouPostKeys.patientId, isEqualTo: userId)
          .get(),
      _firestore
          .collection(FirestoreCollections.todayThankYou)
          .where(ThankYouPostKeys.patientId, isEqualTo: userId)
          .get(),
      _firestore
          .collection(FirestoreCollections.comments)
          .where(CommentKeys.userId, isEqualTo: userId)
          .get(),
    ];

    final results = await Future.wait(futures);
    final postsSnap = results[0] as QuerySnapshot<Map<String, dynamic>>;
    final thankYouSnap = results[1] as QuerySnapshot<Map<String, dynamic>>;
    final todaySnap = results[2] as QuerySnapshot<Map<String, dynamic>>;
    final commentsSnap = results[3] as QuerySnapshot<Map<String, dynamic>>;

    final batchWrites = <WriteBatchOperation>[];

    for (final doc in postsSnap.docs) {
      batchWrites.add((
        ref: _firestore.collection(FirestoreCollections.posts).doc(doc.id),
        data: {FirestorePostKeys.patientName: newNickname},
        isUpdate: true,
      ));
    }
    for (final doc in thankYouSnap.docs) {
      batchWrites.add((
        ref: _firestore.collection(FirestoreCollections.thankYouPosts).doc(doc.id),
        data: {ThankYouPostKeys.patientName: newNickname},
        isUpdate: true,
      ));
    }
    for (final doc in todaySnap.docs) {
      batchWrites.add((
        ref: _firestore.collection(FirestoreCollections.todayThankYou).doc(doc.id),
        data: {ThankYouPostKeys.patientName: newNickname},
        isUpdate: true,
      ));
    }
    for (final doc in commentsSnap.docs) {
      batchWrites.add((
        ref: _firestore.collection(FirestoreCollections.comments).doc(doc.id),
        data: {CommentKeys.userName: newNickname},
        isUpdate: true,
      ));
    }

    if (batchWrites.isEmpty) {
      debugPrint('[NICKNAME_SYNC] : 갱신할 문서 없음');
      return;
    }

    for (var i = 0; i < batchWrites.length; i += _kBatchLimit) {
      final batch = _firestore.batch();
      final chunk = batchWrites.skip(i).take(_kBatchLimit);
      for (final op in chunk) {
        if (op.isUpdate) {
          batch.update(op.ref, op.data);
        }
      }
      await batch.commit();
    }

    debugPrint('[NICKNAME_SYNC] : 완료 — 총 ${batchWrites.length}개 문서 갱신 (posts=${postsSnap.docs.length}, thank_you=${thankYouSnap.docs.length}, today=${todaySnap.docs.length}, comments=${commentsSnap.docs.length})');
  } catch (e, st) {
    debugPrint('[NICKNAME_SYNC] : 실패 — $e');
    debugPrint('[NICKNAME_SYNC] : $st');
    rethrow;
  }
}

typedef WriteBatchOperation = ({
  DocumentReference ref,
  Map<String, dynamic> data,
  bool isUpdate,
});
