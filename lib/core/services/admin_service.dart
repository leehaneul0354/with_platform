// 목적: 관리자 전용 게시물 삭제 등 공통 로직. 권한 재검사 후 Firestore 삭제.
// 흐름: PostDetailScreen·AdminDashboardScreen에서 deletePost 호출 → 권한 체크 → 삭제 → 스낵바는 호출부에서 처리.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../auth/auth_repository.dart';
import '../auth/user_model.dart';
import '../constants/firestore_keys.dart';

/// 삭제 확인 다이얼로그 공통. 제목·내용 지정 가능. 확인 시 true, 취소 시 false.
Future<bool> showDeleteConfirmDialog(
  BuildContext context, {
  String title = '게시물 삭제',
  String content = '정말 이 게시물을 삭제하시겠습니까?',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('삭제'),
        ),
      ],
    ),
  );
  return result == true;
}

/// 게시물 삭제용 확인 다이얼로그 (기존 호출부 호환).
Future<bool> showDeletePostConfirmDialog(BuildContext context) async {
  return showDeleteConfirmDialog(context);
}

/// 관리자 권한 여부 확인 (로컬 + 필요 시 Firestore 재조회)
Future<bool> _ensureAdmin() async {
  var user = AuthRepository.instance.currentUser;
  if (user == null) {
    debugPrint('[SYSTEM] : [ADMIN] deletePost — 로그인되지 않음');
    return false;
  }
  if (user.type == UserType.admin || user.isAdmin) {
    debugPrint('[SYSTEM] : [ADMIN] deletePost — 권한 확인(로컬) type=${user.type.name}');
    return true;
  }
  final fetched = await AuthRepository.instance.fetchUserFromFirestore(user.id);
  final current = AuthRepository.instance.currentUser;
  final allowed = current != null && (current.type == UserType.admin || current.isAdmin);
  debugPrint('[SYSTEM] : [ADMIN] deletePost — Firestore 재조회 후 권한=$allowed');
  return allowed;
}

/// 컬렉션 경로를 받아 문서 삭제. 관리자 권한 확인 후 삭제. 성공 시 true.
/// 게시물(posts)·감사 편지(thank_you_posts) 등 공통 사용.
Future<bool> deleteDocument(String collectionPath, String docId) async {
  try {
    debugPrint('[SYSTEM] : [ADMIN] deleteDocument 요청 — collection=$collectionPath docId=$docId');
    final allowed = await _ensureAdmin();
    if (!allowed) {
      debugPrint('[SYSTEM] : [ADMIN] deleteDocument 거부 — 권한 없음');
      return false;
    }
    await FirebaseFirestore.instance.collection(collectionPath).doc(docId).delete();
    debugPrint('[SYSTEM] : [ADMIN] deleteDocument 완료 — docId=$docId');
    return true;
  } catch (e, st) {
    debugPrint('[SYSTEM] : [ADMIN] deleteDocument 실패 — $e');
    debugPrint('[SYSTEM] : $st');
    return false;
  }
}

/// 게시물 삭제. deleteDocument(posts) 래퍼.
Future<bool> deletePost(String postId) async {
  return deleteDocument(FirestoreCollections.posts, postId);
}

/// 감사 편지(thank_you_posts) 문서 삭제. deleteDocument(thank_you_posts) 래퍼.
Future<bool> deleteThankYouPost(String docId) async {
  return deleteDocument(FirestoreCollections.thankYouPosts, docId);
}

/// 감사 편지 승인: today_thank_you에 문서 추가 후 thank_you_posts 상태를 approved로 변경.
Future<bool> approveThankYouPost(String docId, Map<String, dynamic> data) async {
  try {
    final allowed = await _ensureAdmin();
    if (!allowed) return false;
    final batch = FirebaseFirestore.instance.batch();
    final todayRef = FirebaseFirestore.instance.collection(FirestoreCollections.todayThankYou).doc();
    final Map<String, dynamic> copy = {
      ThankYouPostKeys.title: data[ThankYouPostKeys.title],
      ThankYouPostKeys.content: data[ThankYouPostKeys.content],
      ThankYouPostKeys.imageUrls: data[ThankYouPostKeys.imageUrls],
      ThankYouPostKeys.patientId: data[ThankYouPostKeys.patientId],
      ThankYouPostKeys.patientName: data[ThankYouPostKeys.patientName],
      ThankYouPostKeys.postId: data[ThankYouPostKeys.postId],
      ThankYouPostKeys.postTitle: data[ThankYouPostKeys.postTitle],
      ThankYouPostKeys.type: data[ThankYouPostKeys.type] ?? FirestorePostKeys.typeThanks,
      ThankYouPostKeys.createdAt: FieldValue.serverTimestamp(),
    };
    if (data[ThankYouPostKeys.usagePurpose] != null) {
      copy[ThankYouPostKeys.usagePurpose] = data[ThankYouPostKeys.usagePurpose];
    }
    batch.set(todayRef, copy);
    batch.update(
      FirebaseFirestore.instance.collection(FirestoreCollections.thankYouPosts).doc(docId),
      {ThankYouPostKeys.status: ThankYouPostKeys.approved},
    );
    await batch.commit();
    debugPrint('[SYSTEM] : [ADMIN] approveThankYouPost 완료 — docId=$docId');
    return true;
  } catch (e, st) {
    debugPrint('[SYSTEM] : [ADMIN] approveThankYouPost 실패 — $e');
    debugPrint('[SYSTEM] : $st');
    return false;
  }
}
