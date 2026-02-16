// 목적: 안전한 에셋 이미지 로딩 위젯. 404 에러 및 무한 리빌드 방지.
// 흐름: Image.asset 대신 사용하여 에러 발생 시 즉시 fallback으로 전환.

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// 안전한 에셋 이미지 위젯 (에러 발생 시 즉시 fallback으로 전환)
class SafeImageAsset extends StatelessWidget {
  const SafeImageAsset({
    super.key,
    required this.assetPath,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.fallback,
  });

  final String assetPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    // 경로 정규화: 중복된 assets/ 제거 및 잘못된 경로 수정
    String normalizedPath = assetPath.trim();
    
    // with_mascot.png 같은 존재하지 않는 파일명을 기본값으로 교체
    if (normalizedPath.contains('with_mascot.png')) {
      normalizedPath = 'assets/images/mascot_yellow.png';
    }
    
    // assets/assets/ 패턴 제거
    while (normalizedPath.contains('assets/assets/')) {
      normalizedPath = normalizedPath.replaceFirst('assets/assets/', 'assets/');
    }
    
    // assets/images/로 시작하지 않으면 경로 추가 (파일명만 있는 경우)
    if (!normalizedPath.startsWith('assets/')) {
      normalizedPath = 'assets/images/$normalizedPath';
    } else if (normalizedPath.startsWith('assets/') && !normalizedPath.startsWith('assets/images/')) {
      // assets/로 시작하지만 images/가 없는 경우
      normalizedPath = normalizedPath.replaceFirst('assets/', 'assets/images/');
    }
    
    return Image.asset(
      normalizedPath,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        // 에러 발생 시 즉시 fallback으로 전환 (재시도하지 않음)
        // 무한 루프 방지를 위해 에러 발생 시 fallback만 반환
        return fallback ??
            Container(
              width: width,
              height: height,
              color: Colors.grey.shade200,
              child: Icon(
                Icons.face,
                size: (width != null && height != null)
                    ? (width! < height! ? width! * 0.6 : height! * 0.6)
                    : 48,
                color: AppColors.textSecondary.withValues(alpha: 0.5),
              ),
            );
      },
    );
  }
}
