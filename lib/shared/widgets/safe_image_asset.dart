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
    return Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        // 에러 발생 시 즉시 fallback으로 전환 (재시도하지 않음)
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
