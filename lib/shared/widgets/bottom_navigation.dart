// 목적: 유저 권한별 하단 네비게이션 바. 일반 유저(5개), 관리자(5개) 동적 구성.
// 흐름: 메인 스캐폴드 bottomNavigationBar에 연결, 인덱스에 따라 화면 전환 또는 로그인 유도.
// UI: 아웃라인 스타일 아이콘(Icons.*_outlined) 사용.

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// 하단 메뉴: 권한별 동적 구성
/// 일반 유저: 홈(0), 탐색(1), 작성(2), 투데이(3), 마이페이지(4)
/// 관리자: 홈(0), 관리자 컨트롤 타워(1), 추가(2), 마이페이지(3), 관리자 세부설정(4)
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
  /// true이면 관리자용 5개 탭, false이면 일반 유저용 3개 탭
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final items = isAdmin ? _buildAdminItems() : _buildUserItems();
    
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
      showSelectedLabels: false,
      showUnselectedLabels: false,
      elevation: 8,
    );
  }

  /// 일반 유저용 탭 아이템 (5개) — 아웃라인 아이콘 스타일
  List<BottomNavigationBarItem> _buildUserItems() {
    return [
      const BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined, size: 26),
        activeIcon: Icon(Icons.home, size: 28),
        label: '',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.search_outlined, size: 26),
        activeIcon: Icon(Icons.search, size: 28),
        label: '',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.menu_book_outlined, size: 26),
        activeIcon: Icon(Icons.menu_book, size: 28),
        label: '',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.favorite_border, size: 26),
        activeIcon: Icon(Icons.favorite, size: 28),
        label: '',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person_outline, size: 26),
        activeIcon: Icon(Icons.person, size: 28),
        label: '',
      ),
    ];
  }

  /// 관리자용 탭 아이템 (5개) — 아웃라인 아이콘 스타일
  List<BottomNavigationBarItem> _buildAdminItems() {
    return [
      const BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined, size: 26),
        activeIcon: Icon(Icons.home, size: 28),
        label: '',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.analytics_outlined, size: 26),
        activeIcon: Icon(Icons.analytics, size: 28),
        label: '',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.add_circle_outline, size: 26),
        activeIcon: Icon(Icons.add_circle, size: 28),
        label: '',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person_outline, size: 26),
        activeIcon: Icon(Icons.person, size: 28),
        label: '',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.admin_panel_settings_outlined, size: 26),
        activeIcon: Icon(Icons.admin_panel_settings, size: 28),
        label: '',
      ),
    ];
  }
}
