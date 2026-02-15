// 목적: WITH 메인 화면 — 헤더, 후원 카드, 투데이/피드 토글, 반응형 본문, 하단 네비.
// 흐름: main → WithApp → MainScreen. 로그인 시 닉네임 표시(안녕하세요, [닉네임]님).
// 비로그인에서도 메인 노출; 좌측 상단 사람 아이콘 탭 시 로그인 화면 이동.

import 'package:flutter/material.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/user_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/util/responsive_util.dart';
import '../../shared/widgets/responsive_layout.dart';
import '../../shared/widgets/curved_yellow_header.dart';
import '../../widgets/main_visual_card.dart';
import '../../shared/widgets/today_feed_toggle.dart';
import '../../shared/widgets/bottom_navigation.dart';
import '../../shared/widgets/login_prompt_dialog.dart';
import '../admin/admin_dashboard_screen.dart';
import '../auth/login_screen.dart';
import '../auth/signup_screen.dart';
import 'main_content_desktop.dart';
import 'profile_edit_screen.dart';
import 'main_content_mobile.dart';
import 'my_page_screen.dart';
import '../post/post_upload_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool _isFeedSelected = true;
  int _bottomIndex = 0;

  bool get _isLoggedIn => AuthRepository.instance.currentUser != null;
  String? get _currentNickname => AuthRepository.instance.currentUser?.nickname;

  bool get _isAdmin =>
      AuthRepository.instance.currentUser?.type == UserType.admin ||
      AuthRepository.instance.currentUser?.isAdmin == true;

  void _onBottomTab(int index) {
    final isAdmin = _isAdmin;
    if (!_isLoggedIn && (index == 1 || index == 2 || (isAdmin && index == 3))) {
      LoginPromptDialog.show(
        context,
        onLoginTap: _navigateToLogin,
        onSignupTap: _navigateToSignup,
      );
      return;
    }
    // 관리자 전용 '관리' 탭(인덱스 2) → AdminDashboardScreen으로 이동
    if (isAdmin && index == 2) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
      );
      return;
    }
    setState(() => _bottomIndex = index);
  }

  void _onDonateTap() {
    if (!_isLoggedIn) {
      LoginPromptDialog.show(
        context,
        content: '후원을 진행하시려면 로그인 또는 회원가입을 해 주세요.',
        onLoginTap: _navigateToLogin,
        onSignupTap: _navigateToSignup,
      );
      return;
    }
    // 추후 후원 플로우
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await AuthRepository.instance.ensureAuthSync();
      if (mounted) setState(() {});
    });
  }

  void _navigateToLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _navigateToSignup() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SignupScreen()),
    ).then((_) => setState(() {}));
  }

  void _navigateToProfileEdit() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileEditScreen(
          onLogout: () {
            if (mounted) setState(() {});
          },
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미 첫 화면입니다.')),
        );
      },
      child: Scaffold(
        appBar: CurvedYellowHeader(
          isLoggedIn: _isLoggedIn,
          onPersonTap: _isLoggedIn ? _navigateToProfileEdit : _navigateToLogin,
        ),
        body: IndexedStack(
          index: _bottomIndex.clamp(0, _isAdmin ? 3 : 2),
          children: [
            Column(
              children: [
                if (_currentNickname != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '안녕하세요, $_currentNickname님',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ),
                  ),
                Transform.translate(
                  offset: const Offset(0, -50), //메인화면 상단 노란색 위치조절
                  child: MainVisualCard(
                    amountString: _isLoggedIn ? '2,259,424,122' : '0',
                    subtitle: _isLoggedIn
                        ? '언제 어디서나 간편하게 참여할 수 있는 착한 후원 시스템'
                        : '반갑습니다',
                  ),
                ),
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
                          child: MainContentMobile(
                            isFeedSelected: _isFeedSelected,
                            displayNickname: _currentNickname,
                          ),
                        ),
                      ],
                    ),
                    desktopChild: MainContentDesktop(
                      isFeedSelected: _isFeedSelected,
                      onToggleChanged: (v) => setState(() => _isFeedSelected = v),
                      displayNickname: _currentNickname,
                    ),
                  ),
                ),
              ],
            ),
            Center(
              child: Text(
                '추가 기능 준비 중',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            if (_isAdmin)
              const Center(
                child: Text(
                  '관리',
                  style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
                ),
              ),
            MyPageScreen(
              onLoginTap: _navigateToLogin,
              onSignupTap: _navigateToSignup,
              onLogout: () {
                if (mounted) setState(() => _bottomIndex = 0);
              },
            ),
          ],
        ),
        bottomNavigationBar: ResponsiveHelper.isMobile(context)
            ? BottomNavBar(
                currentIndex: _bottomIndex,
                onTabSelected: _onBottomTab,
                isLoggedIn: _isLoggedIn,
                isAdmin: _isAdmin,
              )
            : null,
        floatingActionButton: ResponsiveHelper.isMobile(context) &&
                AuthRepository.instance.currentUser?.type == UserType.patient
            ? FloatingActionButton(
                onPressed: () {
                  debugPrint('[SYSTEM] : 환자 사연 신청 FAB 탭');
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PostUploadScreen()),
                  );
                },
                backgroundColor: AppColors.yellow,
                child: const Icon(Icons.add, color: AppColors.textPrimary),
              )
            : ResponsiveHelper.isMobile(context)
                ? null
                : Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: ElevatedButton.icon(
                      onPressed: _onDonateTap,
                      icon: const Icon(Icons.favorite_border),
                      label: const Text('나도 후원하기'),
                    ),
                  ),
      ),
    );
  }
}
