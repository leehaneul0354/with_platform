// 목적: ImgBB API로 이미지 업로드. 웹 대응 readAsBytes → base64 → POST 후 data.url 반환.
// 흐름: PostUploadScreen에서 XFile → uploadImageToImgBB → 이미지 URL 확보.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// 나중에 직접 수정할 API 키
String imgbbApiKey = '22024443a8505fbb1b2aa0997a9b2ed9';

const String _imgbbUploadUrl = 'https://api.imgbb.com/1/upload';

/// [pickedFile]을 readAsBytes()로 읽어 ImgBB에 업로드한 뒤, 응답의 data.url을 반환.
/// 실패 시 null. 웹/모바일 공통.
Future<String?> uploadImageToImgBB(XFile pickedFile) async {
  try {
    debugPrint('[SYSTEM] : ImgBB 업로드 시작');
    final bytes = await pickedFile.readAsBytes();
    final base64Image = base64Encode(bytes);
    debugPrint('[SYSTEM] : 이미지 바이트 읽기 완료 (${bytes.length} bytes)');

    final response = await http.post(
      Uri.parse(_imgbbUploadUrl),
      body: {
        'key': imgbbApiKey,
        'image': base64Image,
      },
    );

    if (response.statusCode != 200) {
      debugPrint('[SYSTEM] : ImgBB 업로드 실패 status=${response.statusCode} body=${response.body}');
      return null;
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>?;
    if (json == null) {
      debugPrint('[SYSTEM] : ImgBB 응답 JSON 파싱 실패');
      return null;
    }

    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      debugPrint('[SYSTEM] : ImgBB 응답 data 필드 없음');
      return null;
    }

    final url = data['url'] as String?;
    if (url == null || url.isEmpty) {
      debugPrint('[SYSTEM] : ImgBB data.url 없음');
      return null;
    }

    debugPrint('[SYSTEM] : ImgBB 업로드 성공 url=$url');
    return url;
  } catch (e, st) {
    debugPrint('[SYSTEM] : ImgBB 업로드 예외 $e');
    debugPrint('[SYSTEM] : $st');
    return null;
  }
}
