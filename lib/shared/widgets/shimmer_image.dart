// 목적: 네트워크 이미지 로딩 시 Shimmer 효과 및 에러 처리. 깨진 이미지 대신 플레이스홀더 표시.
// 흐름: StoryFeedCard, PostDetailScreen 등에서 Image.network 대신 사용.

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/assets.dart';

/// Shimmer 효과가 있는 네트워크 이미지 위젯
class ShimmerImage extends StatefulWidget {
  const ShimmerImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  State<ShimmerImage> createState() => _ShimmerImageState();
}

class _ShimmerImageState extends State<ShimmerImage> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  bool _isLoading = true;
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

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;

    if (_hasError) {
      // 에러 시 플레이스홀더 이미지
      imageWidget = Image.asset(
        WithMascots.defaultPlaceholder,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => Container(
          width: widget.width,
          height: widget.height,
          color: AppColors.inactiveBackground,
          child: const Center(
            child: Icon(
              Icons.image_outlined,
              size: 48,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    } else if (_isLoading) {
      // 로딩 중 Shimmer 효과
      imageWidget = AnimatedBuilder(
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
    } else {
      imageWidget = Image.network(
        widget.imageUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
            return child;
          }
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
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _hasError = true;
            });
          }
          return Image.asset(
            WithMascots.defaultPlaceholder,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            errorBuilder: (_, __, ___) => Container(
              width: widget.width,
              height: widget.height,
              color: AppColors.inactiveBackground,
              child: const Center(
                child: Icon(
                  Icons.image_outlined,
                  size: 48,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      );
    }

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}
