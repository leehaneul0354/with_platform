// 목적: 로딩 중일 때 0원 노출 차단용 회색 애니메이션 플레이스홀더.
// 흐름: opacity 0.3~0.7 반복 애니메이션으로 로딩 상태를 시각적으로 표시.

import 'package:flutter/material.dart';

/// 로딩 중 0원 노출 차단용 Shimmer (회색 애니메이션)
class ShimmerPlaceholder extends StatefulWidget {
  const ShimmerPlaceholder({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 32,
    this.duration = const Duration(milliseconds: 1200),
    this.margin,
  });

  final double? width;
  final double? height;
  /// PlatformStatsCard용: horizontal 16. 스켈레톤 내부용: null → EdgeInsets.zero
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Duration duration;

  @override
  State<ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.35, end: 0.65).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Container(
          width: widget.width ?? double.infinity,
          height: widget.height,
          margin: widget.margin ?? EdgeInsets.zero,
          decoration: BoxDecoration(
            color: Colors.grey.shade300.withValues(alpha: _animation.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}
