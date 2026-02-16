// 목적: 댓글 작성·조회·삭제 및 후원자 판별 로직. 각 게시물(사연/감사편지) 하위 comments 서브컬렉션 관리.
// 흐름: 댓글 작성 시 donations 조회로 후원 여부 확인 → isSponsor 필드 저장 → 실시간 스트림으로 표시.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../auth/auth_repository.dart';
import '../auth/user_model.dart';
import '../constants/firestore_keys.dart';

final FirebaseFirestore _firestore = FirebaseFirestore.instance;

/// 댓글 작성. 후원 여부를 자동으로 확인하여 isSponsor 필드에 저장.
/// [postId]: 게시물 ID (posts 또는 thank_you_posts 문서 ID)
/// [postType]: 'post' 또는 'thank_you'
/// [patientId]: 게시물 작성자(수혜자) ID
Future<bool> addComment({
  required String postId,
  required String postType,
  required String userId,
  required String userName,
  required String content,
  required String patientId,
}) async {
  try {
    if (content.trim().isEmpty) {
      debugPrint('[COMMENT] : 댓글 내용이 비어있습니다.');
      return false;
    }

    // 후원 여부 확인: 해당 게시물 후원 여부를 최우선으로 확인
    bool isSponsor = false;
    
    try {
      // 1순위: 해당 게시물(postId)에 직접 후원했는지 확인
      final directDonationQuery = await _firestore
          .collection(FirestoreCollections.donations)
          .where(DonationKeys.userId, isEqualTo: userId)
          .where(DonationKeys.postId, isEqualTo: postId)
          .limit(1)
          .get();
      
      if (directDonationQuery.docs.isNotEmpty) {
        // 해당 게시물에 직접 후원한 기록이 있으면 즉시 뱃지 부여
        isSponsor = true;
        debugPrint('[COMMENT] : 해당 게시물 직접 후원 확인 — 뱃지 부여');
      } else {
        // 2순위: donor 역할이면 자동 인증
        final currentUser = AuthRepository.instance.currentUser;
        if (currentUser != null && currentUser.type == UserType.donor) {
          isSponsor = true;
          debugPrint('[COMMENT] : donor 역할 확인 — 뱃지 부여');
        } else {
          // 3순위: 해당 patientId에게 후원한 기록이 있는지 확인 (기존 로직)
          final donationsQuery = await _firestore
              .collection(FirestoreCollections.donations)
              .where(DonationKeys.userId, isEqualTo: userId)
              .get();

          for (final doc in donationsQuery.docs) {
            final donationData = doc.data();
            final donationPostId = donationData[DonationKeys.postId]?.toString();
            if (donationPostId == null) continue;

            String? targetPatientId;

            if (postType == 'post') {
              // 일반 게시물의 경우 직접 patientId 확인
              final postDoc = await _firestore
                  .collection(FirestoreCollections.posts)
                  .doc(donationPostId)
                  .get();
              if (postDoc.exists) {
                targetPatientId = postDoc.data()?[FirestorePostKeys.patientId]?.toString();
              }
            } else if (postType == 'thank_you') {
              // 감사편지의 경우: donationPostId가 thank_you_posts 문서 ID일 수도 있고,
              // 연결된 원본 게시물(postId)일 수도 있음
              // 먼저 thank_you_posts에서 확인
              final thankYouDoc = await _firestore
                  .collection(FirestoreCollections.thankYouPosts)
                  .doc(donationPostId)
                  .get();
              
              if (thankYouDoc.exists) {
                // thank_you_posts 문서에서 patientId 확인
                targetPatientId = thankYouDoc.data()?[ThankYouPostKeys.patientId]?.toString();
              } else {
                // donationPostId가 원본 게시물 ID일 수도 있음
                final postDoc = await _firestore
                    .collection(FirestoreCollections.posts)
                    .doc(donationPostId)
                    .get();
                if (postDoc.exists) {
                  targetPatientId = postDoc.data()?[FirestorePostKeys.patientId]?.toString();
                }
              }
            }

            if (targetPatientId == patientId) {
              isSponsor = true;
              debugPrint('[COMMENT] : 해당 환자에게 후원 기록 확인 — 뱃지 부여');
              break;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[COMMENT] : 후원 여부 확인 중 오류: $e');
      // 후원 여부 확인 실패해도 댓글은 작성 가능
    }

    // 댓글 저장
    // postType이 'thank_you'인 경우 thank_you_posts 컬렉션 사용
    CollectionReference<Map<String, dynamic>> commentsCollection;
    if (postType == 'thank_you') {
      commentsCollection = _firestore
          .collection(FirestoreCollections.thankYouPosts)
          .doc(postId)
          .collection(FirestoreCollections.comments)
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (snapshot, _) => snapshot.data()!,
            toFirestore: (data, _) => data,
          );
    } else {
      commentsCollection = _firestore
          .collection(FirestoreCollections.posts)
          .doc(postId)
          .collection(FirestoreCollections.comments)
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (snapshot, _) => snapshot.data()!,
            toFirestore: (data, _) => data,
          );
    }

    await commentsCollection.add({
      CommentKeys.content: content.trim(),
      CommentKeys.userId: userId,
      CommentKeys.userName: userName,
      CommentKeys.timestamp: FieldValue.serverTimestamp(),
      CommentKeys.isSponsor: isSponsor,
      CommentKeys.postId: postId,
      CommentKeys.postType: postType,
    });

    debugPrint('[COMMENT] : 댓글 작성 완료 — postId=$postId, isSponsor=$isSponsor');
    return true;
  } catch (e, stackTrace) {
    debugPrint('[COMMENT] : 댓글 작성 실패 — $e');
    debugPrint('[COMMENT] : $stackTrace');
    return false;
  }
}

/// 댓글 목록 스트림 (실시간 업데이트)
Stream<QuerySnapshot<Map<String, dynamic>>> commentsStream({
  required String postId,
  required String postType,
}) {
  CollectionReference<Map<String, dynamic>> commentsCollection;
  if (postType == 'thank_you') {
    commentsCollection = _firestore
        .collection(FirestoreCollections.thankYouPosts)
        .doc(postId)
        .collection(FirestoreCollections.comments)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) => snapshot.data()!,
          toFirestore: (data, _) => data,
        );
  } else {
    commentsCollection = _firestore
        .collection(FirestoreCollections.posts)
        .doc(postId)
        .collection(FirestoreCollections.comments)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) => snapshot.data()!,
          toFirestore: (data, _) => data,
        );
  }

  return commentsCollection
      .orderBy(CommentKeys.timestamp, descending: false)
      .snapshots();
}

/// 댓글 삭제 (작성자 본인 또는 관리자만 가능)
Future<bool> deleteComment({
  required String postId,
  required String postType,
  required String commentId,
  required String userId,
  bool isAdmin = false,
}) async {
  try {
    CollectionReference<Map<String, dynamic>> commentsCollection;
    if (postType == 'thank_you') {
      commentsCollection = _firestore
          .collection(FirestoreCollections.thankYouPosts)
          .doc(postId)
          .collection(FirestoreCollections.comments)
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (snapshot, _) => snapshot.data()!,
            toFirestore: (data, _) => data,
          );
    } else {
      commentsCollection = _firestore
          .collection(FirestoreCollections.posts)
          .doc(postId)
          .collection(FirestoreCollections.comments)
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (snapshot, _) => snapshot.data()!,
            toFirestore: (data, _) => data,
          );
    }

    final commentDoc = await commentsCollection.doc(commentId).get();
    if (!commentDoc.exists) {
      debugPrint('[COMMENT] : 댓글이 존재하지 않습니다.');
      return false;
    }

    final commentData = commentDoc.data();
    final commentUserId = commentData?[CommentKeys.userId]?.toString();

    // 작성자 본인 또는 관리자만 삭제 가능
    if (commentUserId != userId && !isAdmin) {
      debugPrint('[COMMENT] : 삭제 권한이 없습니다.');
      return false;
    }

    await commentsCollection.doc(commentId).delete();
    debugPrint('[COMMENT] : 댓글 삭제 완료 — commentId=$commentId');
    return true;
  } catch (e, stackTrace) {
    debugPrint('[COMMENT] : 댓글 삭제 실패 — $e');
    debugPrint('[COMMENT] : $stackTrace');
    return false;
  }
}
