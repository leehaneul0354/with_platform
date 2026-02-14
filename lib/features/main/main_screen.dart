// 목적: WITH 메인 화면 — 헤더, 후원 카드, 투데이/피드 토글, 반응형 본문, 하단 네비.
// 흐름: main → WithApp → MainScreen. 모바일/데스크톱 분기는 ResponsiveLayout으로 처리.
// 비로그인에서도 메인 노출; 추가/마이페이지·후원하기 클릭 시 로그인 유도.

import 'package:flutter/material.dart';
import '../../core/util/responsive_util.dart';
import '../../shared/widgets/responsive_layout.dart';
import '../../shared/widgets/with_header.dart';
import '../../shared/widgets/donation_progress_card.dart';
import '../../shared/widgets/today_feed_toggle.dart';
import '../../shared/widgets/bottom_navigation.dart';
import '../../shared/widgets/login_prompt_dialog.dart';
import 'main_content_mobile.dart';
import 'main_content_desktop.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool _isFeedSelected = true;
  int _bottomIndex = 0;
  final bool _isLoggedIn = false;

  void _onBottomTab(int index) {
    if (!_isLoggedIn && (index == 1 || index == 2)) {
      LoginPromptDialog.show(context);
      return;
    }
    setState(() => _bottomIndex = index);
  }

  void _onDonateTap() {
    if (!_isLoggedIn) {
      LoginPromptDialog.show(
        context,
        content: '후원을 진행하시려면 로그인 또는 회원가입을 해 주세요.',
      );
      return;
    }
    // 추후 후원 플로우
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const WithHeader(),
      body: Column(
        children: [
          const DonationProgressCard(),
          Expanded(
            child: ResponsiveLayout(
              mobileChild: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TodayFeedToggle(
                    isFeedSelected: _isFeedSelected,
                    onSelectionChanged: (v) => setState(() => _isFeedSelected = v),
                  ),
                  Expanded(
                    child: MainContentMobile(isFeedSelected: _isFeedSelected),
                  ),
                ],
              ),
              desktopChild: MainContentDesktop(
                isFeedSelected: _isFeedSelected,
                onToggleChanged: (v) => setState(() => _isFeedSelected = v),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: ResponsiveHelper.isMobile(context)
          ? BottomNavBar(
              currentIndex: _bottomIndex,
              onTabSelected: _onBottomTab,
              isLoggedIn: _isLoggedIn,
            )
          : null,
      floatingActionButton: ResponsiveHelper.isMobile(context)
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: ElevatedButton.icon(
                onPressed: _onDonateTap,
                icon: const Icon(Icons.favorite_border),
                label: const Text('나도 후원하기'),
              ),
            ),
    );
  }
}
