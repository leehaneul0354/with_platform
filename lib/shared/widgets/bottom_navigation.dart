// 목적: 홈 / 추가(+) / 마이페이지 하단 네비게이션 바.
// 흐름: 메인 스캐폴드 bottomNavigationBar에 연결, 인덱스에 따라 화면 전환 또는 로그인 유도.

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// 하단 3개 메뉴: 홈, 추가, 마이페이지
class BottomNavBar extends StatelessWidget {
  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    this.isLoggedIn = false,
  });

  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final bool isLoggedIn;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex.clamp(0, 2),
      onTap: (int index) {
        onTabSelected(index);
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          label: '홈',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.add_circle_outline),
          label: '추가',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: '마이페이지',
        ),
      ],
      selectedItemColor: AppColors.coral,
      unselectedItemColor: AppColors.textSecondary,
      type: BottomNavigationBarType.fixed,
    );
  }
}
