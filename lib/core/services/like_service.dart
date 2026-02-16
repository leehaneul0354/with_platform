// 목적: 좋아요 토글 기능. 각 게시물(사연/감사편지) 하위 likes 서브컬렉션 관리.
// 흐름: 좋아요 클릭 → 이미 좋아요 했는지 확인 → 없으면 추가, 있으면 삭제 → 실시간 카운트 업데이트.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../constants/firestore_keys.dart';

final FirebaseFirestore _firestore = FirebaseFirestore.instance;

/// 좋아요 토글 (클릭 시 추가/제거)
Future<bool> toggleLike({
  required String postId,
  required String postType,
  required String userId,
}) async {
  try {
    CollectionReference likesCollection;
    if (postType == 'thank_you') {
      likesCollection = _firestore
          .collection(FirestoreCollections.thankYouPosts)
          .doc(postId)
          .collection(FirestoreCollections.likes);
    } else {
      likesCollection = _firestore
          .collection(FirestoreCollections.posts)
          .doc(postId)
          .collection(FirestoreCollections.likes);
    }

    // 이미 좋아요 했는지 확인
    final likeQuery = await likesCollection
        .where(LikeKeys.userId, isEqualTo: userId)
        .limit(1)
        .get();

    if (likeQuery.docs.isNotEmpty) {
      // 이미 좋아요 했으면 제거
      await likesCollection.doc(likeQuery.docs.first.id).delete();
      debugPrint('[LIKE] : 좋아요 제거 — postId=$postId, userId=$userId');
      return false; // 좋아요 해제됨
    } else {
      // 좋아요 추가
      await likesCollection.add({
        LikeKeys.userId: userId,
        LikeKeys.postId: postId,
        LikeKeys.postType: postType,
        LikeKeys.timestamp: FieldValue.serverTimestamp(),
      });
      debugPrint('[LIKE] : 좋아요 추가 — postId=$postId, userId=$userId');
      return true; // 좋아요 추가됨
    }
  } catch (e, stackTrace) {
    debugPrint('[LIKE] : 좋아요 토글 실패 — $e');
    debugPrint('[LIKE] : $stackTrace');
    return false;
  }
}

/// 좋아요 개수 스트림 (실시간 업데이트)
Stream<int> likeCountStream({
  required String postId,
  required String postType,
}) {
  CollectionReference likesCollection;
  if (postType == 'thank_you') {
    likesCollection = _firestore
        .collection(FirestoreCollections.thankYouPosts)
        .doc(postId)
        .collection(FirestoreCollections.likes);
  } else {
    likesCollection = _firestore
        .collection(FirestoreCollections.posts)
        .doc(postId)
        .collection(FirestoreCollections.likes);
  }

  return likesCollection.snapshots().map((snapshot) => snapshot.docs.length);
}

/// 현재 사용자가 좋아요 했는지 여부 스트림
Stream<bool> isLikedStream({
  required String postId,
  required String postType,
  required String userId,
}) {
  CollectionReference likesCollection;
  if (postType == 'thank_you') {
    likesCollection = _firestore
        .collection(FirestoreCollections.thankYouPosts)
        .doc(postId)
        .collection(FirestoreCollections.likes);
  } else {
    likesCollection = _firestore
        .collection(FirestoreCollections.posts)
        .doc(postId)
        .collection(FirestoreCollections.likes);
  }

  return likesCollection
      .where(LikeKeys.userId, isEqualTo: userId)
      .limit(1)
      .snapshots()
      .map((snapshot) => snapshot.docs.isNotEmpty);
}
