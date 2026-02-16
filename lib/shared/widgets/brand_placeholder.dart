// 목적: 게시물 썸네일 부재/실패 시 WITH 브랜드 플레이스홀더. 그라데이션 + 이모지만 사용(에셋 없음).
// 흐름: StoryFeedCard, ShimmerImage, TodayThankYouGrid, PostDetailScreen 등에서 사용.

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// 플레이스홀더 용도
enum PlaceholderVariant {
  /// 썸네일용 (작은 이모지)
  thumbnail,
  /// 본문/상세용 (중간 이모지)
  content,
  /// 감사편지용
  thankYou,
}

/// 이미지가 없거나 로드 실패 시 표시하는 미니멀 플레이스홀더.
/// 노랑-코랄 그라데이션 배경 + 중앙 이모지(에셋 없이 텍스트/아이콘만 사용).
class BrandPlaceholder extends StatelessWidget {
  const BrandPlaceholder({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.variant = PlaceholderVariant.thumbnail,
    this.emoji,
  });

  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final PlaceholderVariant variant;
  /// 지정 시 variant 대신 이 이모지를 사용
  final String? emoji;

  /// 썸네일 영역용 (작은 이모지 ✨)
  static Widget forThumbnail({
    double? width,
    double? height,
    BorderRadius? borderRadius,
  }) {
    return BrandPlaceholder(
      width: width,
      height: height,
      fit: BoxFit.cover,
      borderRadius: borderRadius,
      variant: PlaceholderVariant.thumbnail,
    );
  }

  /// 본문/상세 영역용 (중간 이모지 🧡)
  static Widget forContent({
    double? width,
    double? height,
    BorderRadius? borderRadius,
  }) {
    return BrandPlaceholder(
      width: width,
      height: height,
      fit: BoxFit.contain,
      borderRadius: borderRadius,
      variant: PlaceholderVariant.content,
    );
  }

  /// 감사편지용 (💌)
  static Widget forThankYou({
    double? width,
    double? height,
    BorderRadius? borderRadius,
  }) {
    return BrandPlaceholder(
      width: width,
      height: height,
      fit: BoxFit.cover,
      borderRadius: borderRadius,
      variant: PlaceholderVariant.thankYou,
    );
  }

  String _getEmoji() {
    if (emoji != null && emoji!.isNotEmpty) return emoji!;
    switch (variant) {
      case PlaceholderVariant.thumbnail:
        return '✨';
      case PlaceholderVariant.content:
        return '🧡';
      case PlaceholderVariant.thankYou:
        return '💌';
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = LayoutBuilder(
      builder: (context, constraints) {
        final w = width ?? constraints.maxWidth;
        final h = height ?? constraints.maxHeight;
        final effectiveW = w.isFinite && w > 0 ? w : 200.0;
        final effectiveH = h.isFinite && h > 0 ? h : 200.0;
        final side = (effectiveW < effectiveH ? effectiveW : effectiveH) * 0.28;
        final emojiSize = side.clamp(24.0, 80.0);

        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.yellow.withValues(alpha: 0.2),
                AppColors.coral.withValues(alpha: 0.15),
                AppColors.yellow.withValues(alpha: 0.25),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: Center(
            child: Text(
              _getEmoji(),
              style: TextStyle(
                fontSize: emojiSize,
                height: 1.0,
                color: AppColors.textSecondary.withValues(alpha: 0.7),
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    offset: const Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: content,
      );
    }
    return content;
  }
}
