// 목적: 어드민 게시물(정부 정책/기업 광고/플랫폼 소식) CRUD — Firestore admin_posts.
// 흐름: AdminPostManagementSection → addAdminPost / deleteAdminPost. 탐색 탭 배너용 데이터.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/firestore_keys.dart';

final FirebaseFirestore _firestore = FirebaseFirestore.instance;

/// admin_posts 스트림 (createdAt 내림차순). 탐색 탭 배너 리스트용.
Stream<QuerySnapshot<Map<String, dynamic>>> adminPostsStream() {
  return _firestore
      .collection(FirestoreCollections.adminPosts)
      .orderBy(AdminPostKeys.createdAt, descending: true)
      .snapshots();
}

/// 어드민 게시물 추가. imageUrl·linkUrl은 선택.
Future<void> addAdminPost({
  required String type,
  required String title,
  required String content,
  String? imageUrl,
  String? linkUrl,
  String? badgeText,
}) async {
  await _firestore.collection(FirestoreCollections.adminPosts).add({
    AdminPostKeys.type: type,
    AdminPostKeys.title: title,
    AdminPostKeys.content: content,
    AdminPostKeys.imageUrl: imageUrl,
    AdminPostKeys.linkUrl: linkUrl ?? null,
    AdminPostKeys.badgeText: badgeText ?? null,
    AdminPostKeys.createdAt: FieldValue.serverTimestamp(),
  });
}

/// 어드민 게시물 삭제
Future<void> deleteAdminPost(String docId) async {
  await _firestore.collection(FirestoreCollections.adminPosts).doc(docId).delete();
}
