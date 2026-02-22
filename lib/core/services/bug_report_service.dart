// 목적: 버그 제보 저장 — imgbb API 이미지 업로드, Firestore bug_reports 문서 저장.
// 흐름: BugReportBottomSheet → imgbb 업로드 → 반환 URL → Firestore 저장. Firebase Storage 미사용(CORS·요금 제한 회피).
// 어드민: status 필드(pending/resolved)로 후속 관리 가능.

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../constants/firestore_keys.dart';
import 'imgbb_upload.dart';

final FirebaseFirestore _firestore = FirebaseFirestore.instance;

const String _imgbbUploadUrl = 'https://api.imgbb.com/1/upload';

/// 현재 기기 OS/플랫폼 문자열 (Web, Android, iOS 등)
String get _deviceInfo {
  if (kIsWeb) return 'Web';
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'Android';
    case TargetPlatform.iOS:
      return 'iOS';
    case TargetPlatform.windows:
      return 'Windows';
    case TargetPlatform.macOS:
      return 'macOS';
    case TargetPlatform.linux:
      return 'Linux';
    case TargetPlatform.fuchsia:
      return 'Fuchsia';
  }
}

/// 버그 제보 이미지를 imgbb에 업로드하고 URL 반환. 실패 시 null.
/// 프로젝트 imgbb API 키(imgbbApiKey) 사용. 없으면 imgbb_upload.dart에서 설정.
Future<String?> uploadBugReportImage(String userId, XFile imageFile) async {
  try {
    debugPrint('[BUGREPORT] : ImgBB 업로드 시작');
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final response = await http.post(
      Uri.parse(_imgbbUploadUrl),
      body: {
        'key': imgbbApiKey,
        'image': base64Image,
      },
    );

    if (response.statusCode != 200) {
      debugPrint('[BUGREPORT] : ImgBB 업로드 실패 status=${response.statusCode}');
      return null;
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>?;
    if (json == null) {
      debugPrint('[BUGREPORT] : ImgBB 응답 JSON 파싱 실패');
      return null;
    }

    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      debugPrint('[BUGREPORT] : ImgBB data 필드 없음');
      return null;
    }

    final url = data['url'] as String?;
    if (url == null || url.isEmpty) {
      debugPrint('[BUGREPORT] : ImgBB data.url 없음');
      return null;
    }

    debugPrint('[BUGREPORT] : ImgBB 업로드 성공 url=$url');
    return url;
  } catch (e, st) {
    debugPrint('[BUGREPORT] : ImgBB 업로드 예외 $e');
    debugPrint('[BUGREPORT] : $st');
    return null;
  }
}

/// bug_reports 컬렉션에 문서 저장. imageUrl 없으면 null.
Future<void> submitBugReport({
  required String userId,
  required String content,
  String? imageUrl,
}) async {
  await _firestore.collection(FirestoreCollections.bugReports).add({
    BugReportKeys.userId: userId,
    BugReportKeys.content: content,
    BugReportKeys.imageUrl: imageUrl,
    BugReportKeys.status: BugReportKeys.statusPending,
    BugReportKeys.createdAt: FieldValue.serverTimestamp(),
    BugReportKeys.deviceInfo: _deviceInfo,
  });
  debugPrint('[BUGREPORT] : 제보 저장 완료 userId=$userId');
}

/// 관리자용: bug_reports 문서의 status를 resolved로 업데이트
Future<void> updateBugReportStatus(String docId, String status) async {
  await _firestore.collection(FirestoreCollections.bugReports).doc(docId).update({
    BugReportKeys.status: status,
  });
  debugPrint('🚩 [LOG] AdminBugReport: 제보 상태 업데이트 완료 (ID: $docId, Status: $status)');
}
