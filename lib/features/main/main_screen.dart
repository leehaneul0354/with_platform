// 목적: WITH 메인 화면 — 헤더, 후원 카드, 투데이/피드 토글, 반응형 본문, 하단 네비.
// 흐름: main → WithApp → MainScreen. 로그인 시 닉네임 표시(안녕하세요, [닉네임]님).
// 비로그인에서도 메인 노출; 좌측 상단 사람 아이콘 탭 시 로그인 화면 이동.

import 'package:flutter/material.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/user_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/navigation/app_route_observer.dart';
import '../../core/util/responsive_util.dart';
import '../../shared/widgets/responsive_layout.dart';
import '../../shared/widgets/curved_yellow_header.dart';
import '../../shared/widgets/approved_posts_feed.dart';
import '../../shared/widgets/hope_message_card.dart';
import '../../shared/widgets/today_feed_toggle.dart';
import '../../shared/widgets/bottom_navigation.dart';
import '../../shared/widgets/donor_rank_list.dart';
import '../../shared/widgets/today_thank_you_grid.dart';
import '../../shared/widgets/login_prompt_dialog.dart';
import '../admin/admin_dashboard_screen.dart';
import '../admin/admin_main_screen.dart';
import '../auth/login_screen.dart';
import '../auth/signup_screen.dart';
import 'main_content_desktop.dart';
import 'profile_edit_screen.dart';
import 'main_content_mobile.dart';
import 'my_page_screen.dart';
import 'diary_screen.dart';
import 'explore_screen.dart';
import 'post_create_choice_screen.dart';
import 'today_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with RouteAware {
  bool _isFeedSelected = true;
  int _bottomIndex = 0;
  final GlobalKey _exploreKey = GlobalKey();
  /// 통신 지연/갱신 중에도 관리자 UI 유지. 로그아웃 시에만 false로 리셋.
  bool _lastKnownAdmin = false;

  /// 워터폴 로딩: 탭별 스트림 구독 시차 (Firestore ca9/b815 충돌 방지)
  bool _isStreamTab0Ready = false; // 홈 피드 (500ms)
  bool _isStreamTab1Ready = false; // 탐색 (1000ms)
  bool _isStreamTab3Ready = false; // 투데이 (1500ms)

  @override
  void initState() {
    super.initState();
    _scheduleWaterfallStreamInit();
  }

  /// 워터폴: 탭 0(500ms) → 탭 1(1000ms) → 탭 3(1500ms) 순차 스트림 활성화
  void _scheduleWaterfallStreamInit() {
    debugPrint('🚩 [LOG] 워터폴 로딩 시작: 홈 탭');
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final user = AuthRepository.instance.currentUser;
      if (user == null) {
        debugPrint('🚩 [LOG] MainScreen - 유저 null, 동기화 스킵 (탭 인덱스 유지)');
        _lastKnownAdmin = false;
      } else {
        if (!AuthRepository.instance.isLoggingOut) {
          await AuthRepository.instance.ensureAuthSync();
          if (!mounted) return;
        }
      }
      try {
        initializeApprovedPostsStream(force: false);
      } catch (e) {
        await Future.delayed(const Duration(milliseconds: 200));
        try {
          initializeApprovedPostsStream(force: true);
        } catch (_) {}
      }
      // 탭 0: 500ms
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      setState(() {
        _phaseFeedReady = true;
        _isStreamTab0Ready = true;
      });
      // 탭 1: 1000ms (추가 500ms)
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      setState(() => _isStreamTab1Ready = true);
      // 탭 3: 1500ms (추가 500ms)
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      setState(() => _isStreamTab3Ready = true);
      debugPrint('🚩 [LOG] Firestore 엔진 안정화 및 시차 로딩 적용 완료');
    });
  }

  bool get _isLoggedIn => AuthRepository.instance.currentUser != null;
  String? get _currentNickname => AuthRepository.instance.currentUser?.nickname;

  /// currentUser 기준 + 마지막으로 알려진 admin 상태로 5탭 유지(권한 유실 방지)
  bool get _isAdmin {
    final cur = AuthRepository.instance.currentUser;
    if (cur == null) {
      _lastKnownAdmin = false;
      return false;
    }
    final isAdmin = cur.type == UserType.admin || cur.isAdmin == true;
    if (isAdmin) _lastKnownAdmin = true;
    return isAdmin || _lastKnownAdmin;
  }

  void _onBottomTab(int index) {
    // 일반 유저: 홈(0), 탐색(1), 작성(2), 투데이(3), 마이페이지(4)
    // 관리자: 홈(0), 컨트롤타워(1), 추가(2), 마이페이지(3), 관리자설정(4)
    
    if (_isAdmin) {
      _handleAdminTab(index);
    } else {
      // 일반 유저 5탭 처리
      switch (index) {
        case 0: // 홈
          setState(() => _bottomIndex = 0);
          break;
        case 1: // 탐색
          if (_bottomIndex == 1) {
            // 이미 탐색 탭인 상태에서 탐색 아이콘 다시 클릭: 순서 유지, 스크롤만 상단으로
            final state = _exploreKey.currentState;
            if (state != null) {
              // _ExploreScreenState.scrollToTop() 호출 (타입은 private이므로 dynamic 사용)
              // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
              (state as dynamic).scrollToTop();
            }
          } else {
            // 다른 탭 → 탐색 탭 진입: 게시물 순서 새로 섞기 (refreshOrder) + 탭 전환
            final state = _exploreKey.currentState;
            if (state != null) {
              // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
              (state as dynamic).refreshOrder();
            }
            setState(() => _bottomIndex = 1);
          }
          break;
        case 2: // 작성
        case 3: // 투데이
          setState(() => _bottomIndex = index);
          break;
        case 4: // 마이페이지
          if (!_isLoggedIn) {
            LoginPromptDialog.show(
              context,
              onLoginTap: _navigateToLogin,
              onSignupTap: _navigateToSignup,
            );
            return;
          }
          setState(() => _bottomIndex = 4);
          break;
      }
    }
  }

  /// 관리자 탭 처리 (5개 탭)
  void _handleAdminTab(int index) {
    // 로그인 필요 체크
    if (!_isLoggedIn && index != 0) {
      LoginPromptDialog.show(
        context,
        onLoginTap: _navigateToLogin,
        onSignupTap: _navigateToSignup,
      );
      return;
    }

    switch (index) {
      case 0: // 홈
        setState(() => _bottomIndex = 0);
        break;
      case 1: // 관리자 컨트롤 타워 (AdminMainScreen)
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AdminMainScreen()),
        ).then((_) {
          if (mounted) setState(() {});
        });
        break;
      case 2: // 추가 (사연등록)
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PostCreateChoiceScreen()),
        ).then((_) {
          if (mounted) setState(() {});
        });
        break;
      case 3: // 마이페이지
        setState(() => _bottomIndex = 3);
        break;
      case 4: // 관리자 세부설정 (AdminDashboardScreen)
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
        ).then((_) {
          if (mounted) setState(() {});
        });
        break;
    }
  }

  /// 일반 유저 탭 처리 (3개 탭)
  void _handleUserTab(int index) {
    debugPrint('[MAIN_SCREEN] : 일반 유저 탭 클릭 - index: $index, isLoggedIn: $_isLoggedIn');
    
    switch (index) {
      case 0: // 홈
        setState(() => _bottomIndex = 0);
        break;
      case 1: // 사연등록
        // 로그인 필요 체크
        if (!_isLoggedIn) {
          LoginPromptDialog.show(
            context,
            onLoginTap: _navigateToLogin,
            onSignupTap: _navigateToSignup,
          );
          return;
        }
        // 모든 유저(후원자, 환자, 일반회원)가 접근 가능
        debugPrint('[MAIN_SCREEN] : 사연등록 화면으로 이동');
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PostCreateChoiceScreen()),
        ).then((_) {
          // 화면 복귀 시 상태 갱신
          if (mounted) setState(() {});
        });
        break;
      case 2: // 마이페이지
        // 로그인 필요 체크
        if (!_isLoggedIn && index != 0) {
          LoginPromptDialog.show(
            context,
            onLoginTap: _navigateToLogin,
            onSignupTap: _navigateToSignup,
          );
          return;
        }
        setState(() => _bottomIndex = 2);
        break;
    }
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

  /// 폭포수형 로딩: 유저 확인 → 피드 허용 → 탭별 스트림 시차 (동시 구독 병목 방지)
  bool _phaseFeedReady = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.unsubscribe(this);
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    super.didPopNext();
    _refreshUserAndSyncUI();
  }

  /// 하위 화면에서 복귀 시 Firestore에서 최신 유저(role 포함) 로드 후 UI 동기화
  Future<void> _refreshUserAndSyncUI() async {
    final userId = AuthRepository.instance.currentUser?.id;
    if (userId != null) {
      await AuthRepository.instance.fetchUserFromFirestore(userId);
    }
    if (mounted) setState(() {});
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
    final userId = AuthRepository.instance.currentUser?.id;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileEditScreen(
          onLogout: () {
            if (mounted) setState(() {});
          },
        ),
      ),
    ).then((_) async {
      if (!mounted) return;
      // 프로필 복귀 시 Firestore에서 최신 유저(role 포함) 로드 후 UI 강제 동기화 — 관리자 5탭 유지
      if (userId != null) {
        await AuthRepository.instance.fetchUserFromFirestore(userId);
      }
      if (mounted) setState(() {});
    });
  }

  /// IndexedStack/화면 인덱스 매핑
  /// 일반 유저: 0=홈, 1=탐색, 2=작성, 3=투데이, 4=마이페이지
  /// 관리자: 0=홈, 1=마이페이지 (나머지는 Navigator.push)
  int _getIndexedStackIndex() {
    if (_isAdmin) {
      return _bottomIndex == 3 ? 1 : 0;
    }
    return _bottomIndex;
  }

  /// 일반 유저 5탭 children — 스트림 시차 플래그 전달 (워터폴)
  List<Widget> _buildUserTabChildren() {
    return [
      KeyedSubtree(
        key: ValueKey(_isStreamTab0Ready),
        child: _buildHomeContent(),
      ),
      ExploreScreen(
        key: _exploreKey,
        streamEnabled: _isStreamTab1Ready,
      ),
      DiaryScreen(
        onLoginTap: _navigateToLogin,
        onSignupTap: _navigateToSignup,
      ),
      TodayScreen(streamEnabled: _isStreamTab3Ready),
      MyPageScreen(
        onLoginTap: _navigateToLogin,
        onSignupTap: _navigateToSignup,
        onLogout: () {
          if (mounted) setState(() => _bottomIndex = 0);
        },
      ),
    ];
  }

  /// 홈 콘텐츠 위젯
  Widget _buildHomeContent() {
    return ResponsiveLayout(
      mobileChild: _buildMobileHomeScroll(),
      desktopChild: Column(
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
            offset: const Offset(0, -50),
            child: const HopeMessageCard(),
          ),
          Expanded(
            child: MainContentDesktop(
              isFeedSelected: _isFeedSelected,
              onToggleChanged: (v) => setState(() => _isFeedSelected = v),
              displayNickname: _currentNickname,
            ),
          ),
        ],
      ),
    );

  }

  /// IndexedStack의 children — 일반 유저 5탭 / 관리자 2탭
  List<Widget> _buildIndexedStackChildren() {
    if (_isAdmin) {
      return [
        KeyedSubtree(
          key: ValueKey(_isStreamTab0Ready),
          child: _buildHomeContent(),
        ),
        MyPageScreen(
          onLoginTap: _navigateToLogin,
          onSignupTap: _navigateToSignup,
          onLogout: () {
            if (mounted) setState(() => _bottomIndex = 0);
          },
        ),
      ];
    }
    return _buildUserTabChildren();
  }


  /// BottomNavigationBar의 currentIndex 계산
  int _getBottomNavIndex() {
    return _bottomIndex.clamp(0, 4);
  }

  /// 모바일 홈: 노란 바만 pinned, 핑크 카드·피드까지 한 번에 스크롤 (CustomScrollView + SliverAppBar).
  Widget _buildMobileHomeScroll() {
    const double _headerHeight = 56 + 14 + 8; // CurvedYellowHeader preferred height
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: _headerHeight,
          toolbarHeight: _headerHeight,
          flexibleSpace: SizedBox.expand(
            child: CurvedYellowHeader(
              isLoggedIn: _isLoggedIn,
              onPersonTap: _isLoggedIn ? _navigateToProfileEdit : _navigateToLogin,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: HopeMessageCard(),
              ),
              const SizedBox(height: 8),
              TodayFeedToggle(
                isFeedSelected: _isFeedSelected,
                onSelectionChanged: (v) => setState(() => _isFeedSelected = v),
              ),
            ],
          ),
        ),
        if (_isFeedSelected) ...[
          if (_phaseFeedReady)
            const ApprovedPostsFeedSliver()
          else
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
          const CompletedPostsSliver(),
        ] else
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DonorRankListFromFirestore(
                  title: '오늘의 베스트 후원자',
                  topN: 5,
                ),
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '환자들의 감사편지',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const TodayThankYouGrid(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  spacing: 8,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // 탭 인덱스는 _onBottomTab에서만 제어. build() 내 유저 null 시 리다이렉트 제거 (튕김 방지)
    final isMobile = ResponsiveHelper.isMobile(context);
    // 홈(0): body 내 SliverAppBar. Explore/Diary/Today(1,2,3): 자체 AppBar. 마이페이지(4): CurvedYellowHeader.
    final showHeaderInBody = isMobile && _bottomIndex == 0;
    final isMyPageTab = (_bottomIndex == 4 && !_isAdmin) || (_bottomIndex == 3 && _isAdmin);
    final showMainAppBar = !showHeaderInBody && isMyPageTab;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미 첫 화면입니다.')),
        );
      },
      child: Scaffold(
        appBar: showMainAppBar
            ? CurvedYellowHeader(
                isLoggedIn: _isLoggedIn,
                onPersonTap: _isLoggedIn ? _navigateToProfileEdit : _navigateToLogin,
              )
            : null,
        body: SafeArea(
          top: !showHeaderInBody, // 모바일 홈일 때는 SliverAppBar가 있으므로 top false
          bottom: true,
          child: IndexedStack(
            index: _getIndexedStackIndex(),
            children: _buildIndexedStackChildren(),
          ),
        ),
        bottomNavigationBar: isMobile
            ? BottomNavBar(
                currentIndex: _getBottomNavIndex(),
                onTabSelected: _onBottomTab,
                isLoggedIn: _isLoggedIn,
                isAdmin: _isAdmin,
              )
            : null,
        floatingActionButton: isMobile
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

