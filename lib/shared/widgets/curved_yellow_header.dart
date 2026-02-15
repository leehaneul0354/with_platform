// 목적: UI2 디자인 — 노란색(#FFD400) U자 곡선 배경 + WITH 헤더.
// 흐름: CustomPainter로 하단이 부드럽게 처진 곡선을 그려 헤더 영역 구성.

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// UI2 시안 Yellow #FFD400
const Color _headerYellow = Color(0xFFFFD400);

/// U자형 곡선 노란 배경 + 좌측 사람 아이콘, 중앙 WITH, 우측 종 모양 알림 아이콘
class CurvedYellowHeader extends StatelessWidget implements PreferredSizeWidget {
  const CurvedYellowHeader({
    super.key,
    this.showBackButton = false,
    this.onNotificationTap,
    this.onPersonTap,
  });

  final bool showBackButton;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onPersonTap;

  static const double _curveExtension = 16;
  static const double _curveHeight = 28;
  static const double _toolbarHeight = kToolbarHeight;

  @override
  Size get preferredSize => const Size.fromHeight(_toolbarHeight + _curveHeight + _curveExtension);

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _CurvedYellowClipper(),
      child: Container(
        width: double.infinity,
        color: _headerYellow,
        child: SafeArea(
          top: true,
          bottom: false,
          child: Column(
            children: [
              SizedBox(
                height: _toolbarHeight,
                child: _buildToolbar(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    Widget? leading;
    if (showBackButton) {
      leading = IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
        onPressed: () => Navigator.of(context).maybePop(),
      );
    } else if (onPersonTap != null) {
      leading = IconButton(
        icon: const Icon(Icons.person_outline, color: AppColors.textPrimary),
        onPressed: onPersonTap,
      );
    }

    return Row(
      children: [
        if (leading != null) leading,
        const Spacer(),
        const Text(
          'WITH',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary),
          onPressed: onNotificationTap ?? () {},
        ),
      ],
    );
  }
}

/// 하단이 U자형으로 처지는 ClipPath (중앙이 아래로 부드럽게 곡선)
class _CurvedYellowClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final h = size.height;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, h)
      ..quadraticBezierTo(size.width * 0.5, h + 28, 0, h)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
