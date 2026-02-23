// 목적: gs:// Firebase Storage URL을 getDownloadURL()로 HTTPS URL로 변환. 메모리 캐시로 재요청 방지.
// 중요: 문자열 치환이 아니라 refFromURL(gsUrl).getDownloadURL()로 '다운로드 토큰이 포함된 완전한 URL'만 사용.
// 하이브리드: https:// 등 gs://가 아닌 URL은 변환 없이 즉시 그대로 반환. gs://만 변환.
// 흐름: 이미지 URL이 gs://로 시작하면 refFromURL → getDownloadURL → 캐시 저장 → 반환.

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

final FirebaseStorage _storage = FirebaseStorage.instance;

/// gs:// → HTTPS 변환 결과 캐시 (메모리). 앱 생존 동안 유지.
final Map<String, String> _gsToHttpsCache = {};

/// URL이 gs://로 시작하면 getDownloadURL()로 HTTPS URL 반환. https:// 등 그 외 스킴은 변환 없이 즉시 반환.
/// 리스트의 첫 항목(imageUrls[0]) 등 어떤 형식이든 이 함수 하나로 통일 처리 가능.
Future<String?> resolveImageUrl(String? url) async {
  if (url == null || url.trim().isEmpty) return null;
  final trimmed = url.trim();
  if (!trimmed.toLowerCase().startsWith('gs://')) return trimmed;

  if (_gsToHttpsCache.containsKey(trimmed)) {
    return _gsToHttpsCache[trimmed];
  }
  try {
    final ref = _storage.refFromURL(trimmed);
    final httpsUrl = await ref.getDownloadURL();
    _gsToHttpsCache[trimmed] = httpsUrl;
    debugPrint('[GS_URL] : 캐시 저장 gs://... → ${httpsUrl.substring(0, 50)}...');
    return httpsUrl;
  } catch (e, st) {
    debugPrint('[GS_URL] : getDownloadURL 실패 $e');
    debugPrint('[GS_URL] : $st');
    return null;
  }
}

/// resolveImageUrl과 동일. 별칭으로 GsUrlResolver.resolve() 스타일 호출 가능.
Future<String?> resolve(String? url) => resolveImageUrl(url);

/// gs:// → HTTPS 변환 결과 캐시 초기화 (슬리버 새로고침 등 force 리프레시 시 사용).
void clearResolvedImageUrlCache() {
  _gsToHttpsCache.clear();
  debugPrint('[GS_URL] : 캐시 초기화');
}
