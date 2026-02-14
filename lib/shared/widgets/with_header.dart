// 목적: WITH 로고 + 알림 아이콘이 있는 노란색 배경 헤더.
// 흐름: 메인/서브 화면 상단에 배치, 뒤로가기 옵션 지원.

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// WITH 로고와 알림 아이콘을 가진 상단 헤더
class WithHeader extends StatelessWidget implements PreferredSizeWidget {
  const WithHeader({
    super.key,
    this.showBackButton = false,
    this.onNotificationTap,
  });

  /// true면 왼쪽에 뒤로가기 버튼 표시
  final bool showBackButton;

  /// 알림 아이콘 탭 콜백 (null이면 아이콘만 표시)
  final VoidCallback? onNotificationTap;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.yellow,
      elevation: 0,
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).maybePop(),
            )
          : null,
      title: const Text(
        'WITH',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: onNotificationTap ?? () {},
        ),
      ],
    );
  }
}
