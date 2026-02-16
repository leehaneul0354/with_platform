// 목적: 네트워크 이미지 로딩 시 Shimmer 효과 및 에러 처리. 깨진 이미지 대신 플레이스홀더 표시.
// 흐름: StoryFeedCard, PostDetailScreen 등에서 사용. Image.network는 첫 프레임부터 트리에 넣어 실제 로드가 일어나도록 함.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import 'brand_placeholder.dart';

/// Shimmer 효과가 있는 네트워크 이미지 위젯.
/// 항상 네트워크 이미지를 트리에 넣어 로드가 시작되고, loadingBuilder/errorBuilder로 UI 처리.
class ShimmerImage extends StatefulWidget {
  const ShimmerImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.errorPlaceholderEmoji,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  /// 이미지 로드 실패 시 플레이스홀더 이모지 (예: '📄' 일반 기록, '🤝' 후원 요청)
  final String? errorPlaceholderEmoji;

  @override
  State<ShimmerImage> createState() => _ShimmerImageState();
}

class _ShimmerImageState extends State<ShimmerImage> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Widget _buildShimmerBox() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1.0 - _shimmerController.value * 2, 0),
              end: Alignment(1.0 - _shimmerController.value * 2, 0),
              colors: [
                AppColors.inactiveBackground,
                AppColors.inactiveBackground.withValues(alpha: 0.5),
                AppColors.inactiveBackground,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    return BrandPlaceholder(
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      borderRadius: widget.borderRadius,
      emoji: widget.errorPlaceholderEmoji,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError || widget.imageUrl.trim().isEmpty) {
      final placeholder = _buildPlaceholder();
      if (widget.borderRadius != null) {
        return ClipRRect(
          borderRadius: widget.borderRadius!,
          child: placeholder,
        );
      }
      return placeholder;
    }

    // 항상 네트워크 이미지를 트리에 넣어 로드가 시작되도록 함 (이전에는 _isLoading일 때 미빌드로 로드 안 됨)
    final imageWidget = CachedNetworkImage(
      imageUrl: widget.imageUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      placeholder: (context, url) => _buildShimmerBox(),
      errorWidget: (context, url, error) {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _hasError = true);
          });
        }
        return _buildPlaceholder();
      },
    );

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}
