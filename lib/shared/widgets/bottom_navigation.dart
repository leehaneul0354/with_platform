// 목적: 홈 / 추가(+) / 마이페이지 하단 네비게이션 바. 관리자일 때만 '관리' 탭 추가.
// 흐름: 메인 스캐폴드 bottomNavigationBar에 연결, 인덱스에 따라 화면 전환 또는 로그인 유도.

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// 하단 메뉴: 홈, 추가, (관리자일 때만) 관리, 마이페이지
class BottomNavBar extends StatelessWidget {
  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    this.isLoggedIn = false,
    this.isAdmin = false,
  });

  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final bool isLoggedIn;
  /// true이면 '관리' 탭이 노출되고, 탭 시 onTabSelected(2) 호출
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final items = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined),
        label: '홈',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.add_circle_outline),
        label: '추가',
      ),
      if (isAdmin)
        const BottomNavigationBarItem(
          icon: Icon(Icons.admin_panel_settings_outlined),
          label: '관리',
        ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person_outline),
        label: '마이페이지',
      ),
    ];
    final maxIndex = items.length - 1;
    return BottomNavigationBar(
      currentIndex: currentIndex.clamp(0, maxIndex),
      onTap: (int index) {
        onTabSelected(index);
      },
      items: items,
      selectedItemColor: AppColors.coral,
      unselectedItemColor: AppColors.textSecondary,
      type: BottomNavigationBarType.fixed,
    );
  }
}
