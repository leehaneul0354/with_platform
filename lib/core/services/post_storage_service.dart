// 목적: 게시물 이미지를 Firebase Storage 'posts/' 경로에 업로드 후 download URL 반환.
// 흐름: PostUploadScreen 등에서 XFile → uploadPostImage → posts/post_${timestamp}.jpg → getDownloadURL.

import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

final FirebaseStorage _storage = FirebaseStorage.instance;

/// 게시물 이미지를 Storage 'posts/' 폴더에 업로드하고 download URL 반환. 실패 시 null.
/// 파일명: posts/post_${DateTime.now().millisecondsSinceEpoch}.jpg (고정 .jpg 확장자)
Future<String?> uploadPostImage(XFile imageFile) async {
  try {
    debugPrint('[POST_STORAGE] : 업로드 시작');
    final bytes = await imageFile.readAsBytes();
    final path = 'posts/post_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref().child(path);
    await ref.putData(Uint8List.fromList(bytes));
    final url = await ref.getDownloadURL();
    debugPrint('[POST_STORAGE] : 업로드 성공 $path');
    return url;
  } catch (e, st) {
    debugPrint('[POST_STORAGE] : 업로드 실패 $e');
    debugPrint('[POST_STORAGE] : $st');
    return null;
  }
}
