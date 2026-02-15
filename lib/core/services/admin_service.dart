// 목적: 관리자 전용 게시물 삭제 등 공통 로직. 권한 재검사 후 Firestore 삭제.
// 흐름: PostDetailScreen·AdminDashboardScreen에서 deletePost 호출 → 권한 체크 → 삭제 → 스낵바는 호출부에서 처리.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../auth/auth_repository.dart';
import '../auth/user_model.dart';
import '../constants/firestore_keys.dart';

/// 삭제 확인 다이얼로그 공통. 확인 시 true, 취소 시 false.
Future<bool> showDeletePostConfirmDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('게시물 삭제'),
      content: const Text('정말 이 게시물을 삭제하시겠습니까?'),
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

/// 게시물 삭제. 현재 유저가 admin인지 Firestore/Auth 레벨에서 재확인 후 삭제. 성공 시 true.
Future<bool> deletePost(String postId) async {
  try {
    debugPrint('[SYSTEM] : [ADMIN] deletePost 요청 — postId=$postId');
    final allowed = await _ensureAdmin();
    if (!allowed) {
      debugPrint('[SYSTEM] : [ADMIN] deletePost 거부 — 권한 없음');
      return false;
    }
    await FirebaseFirestore.instance
        .collection(FirestoreCollections.posts)
        .doc(postId)
        .delete();
    debugPrint('[SYSTEM] : [ADMIN] deletePost 완료 — postId=$postId');
    return true;
  } catch (e, st) {
    debugPrint('[SYSTEM] : [ADMIN] deletePost 실패 — $e');
    debugPrint('[SYSTEM] : $st');
    return false;
  }
}
