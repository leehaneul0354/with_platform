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
import '../../shared/widgets/platform_stats_card.dart';
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
import 'post_create_choice_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with RouteAware {
  bool _isFeedSelected = true;
  int _bottomIndex = 0;
  /// 통신 지연/갱신 중에도 관리자 UI 유지. 로그아웃 시에만 false로 리셋.
  bool _lastKnownAdmin = false;

  @override
  void initState() {
    super.initState();
    // 로그아웃 후 상태 초기화를 위해 user 상태 확인
    // 주의: ensureAuthSync는 로그아웃 중에는 실행되지 않음 (AuthRepository에서 차단됨)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      
      // 유저가 null이면 어떤 데이터 로드도 하지 않음 (로그아웃 후 세션 부활 방지)
      final user = AuthRepository.instance.currentUser;
      if (user == null) {
        debugPrint('🚩 [LOG] MainScreen - 유저가 null이므로 모든 데이터 로드 스킵 (세션 부활 방지)');
        _lastKnownAdmin = false;
        _bottomIndex = 0;
        // 유저가 null일 때는 ensureAuthSync를 절대 호출하지 않음
        // 이렇게 해야 로그아웃 후 SharedPreferences에서 데이터를 다시 읽어오는 것을 방지
      } else {
        // 유저가 있을 때만 동기화 실행 (로그아웃 중이 아닐 때만)
        if (!AuthRepository.instance.isLoggingOut) {
          await AuthRepository.instance.ensureAuthSync();
          if (!mounted) return;
        } else {
          debugPrint('🚩 [LOG] MainScreen - 로그아웃 진행 중이므로 ensureAuthSync 스킵');
        }
      }
      
      // 피드 스트림 초기화 확인 및 강제 초기화 (안정성 강화)
      try {
        initializeApprovedPostsStream(force: false);
        debugPrint('🚩 [LOG] MainScreen - 피드 스트림 초기화 확인 완료');
      } catch (e) {
        debugPrint('🚩 [LOG] MainScreen - 피드 스트림 초기화 실패, 재시도: $e');
        await Future.delayed(const Duration(milliseconds: 200));
        try {
          initializeApprovedPostsStream(force: true);
          debugPrint('🚩 [LOG] MainScreen - 피드 스트림 강제 초기화 완료');
        } catch (e2) {
          debugPrint('🚩 [LOG] MainScreen - 피드 스트림 강제 초기화 실패: $e2');
        }
      }
      
      // 스트림 구독 순차 지연: 피드 데이터 → 잔액 스트림 순서로 로드 (Firestore 충돌 방지)
      // 1단계: 피드 데이터 스트림 준비 (300ms 지연)
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() => _phaseFeedReady = true);
      debugPrint('🚩 [LOG] MainScreen - 피드 데이터 스트림 준비 완료');
      
      // 2단계: 통계/잔액 스트림 준비 (추가 300ms 지연 - 총 600ms)
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() => _phaseStatsReady = true);
      debugPrint('🚩 [LOG] MainScreen - 통계/잔액 스트림 준비 완료');
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
    // 일반 유저의 경우: 홈(0), 사연등록(1), 마이페이지(2)
    // 관리자의 경우: 홈(0), 컨트롤타워(1), 추가(2), 마이페이지(3), 관리자설정(4)
    
    if (_isAdmin) {
      // 관리자 탭 처리 (5개 탭)
      _handleAdminTab(index);
    } else {
      // 일반 유저 탭 처리 (3개 탭)
      switch (index) {
        case 0: // 홈
          setState(() => _bottomIndex = 0);
          break;
        case 1: // 사연등록 - 즉시 처리
          if (!_isLoggedIn) {
            LoginPromptDialog.show(
              context,
              onLoginTap: _navigateToLogin,
              onSignupTap: _navigateToSignup,
            );
            return;
          }
          // PostCreateChoiceScreen으로 즉시 이동
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PostCreateChoiceScreen()),
          );
          break;
        case 2: // 마이페이지
          if (!_isLoggedIn) {
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

  /// 폭포수형 로딩: 유저 확인 → 300ms → 피드 허용 → 300ms → 잔액/후원 현황 허용 (동시 구독 병목 방지)
  bool _phaseFeedReady = false;
  bool _phaseStatsReady = false;

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

  /// IndexedStack의 인덱스 계산
  /// 홈(0)과 마이페이지만 IndexedStack에 포함, 나머지는 Navigator.push로 처리
  int _getIndexedStackIndex() {
    if (_isAdmin) {
      // 관리자: 홈(0) 또는 마이페이지(3)일 때만 IndexedStack 사용
      return _bottomIndex == 3 ? 1 : 0;
    } else {
      // 일반 유저: 홈(0) 또는 마이페이지(2)일 때만 IndexedStack 사용
      return _bottomIndex == 2 ? 1 : 0;
    }
  }

  /// IndexedStack의 children 동적 생성 (홈, 마이페이지만 포함)
  List<Widget> _buildIndexedStackChildren() {
    final homeScreen = ResponsiveLayout(
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
            child: PlatformStatsCard(
              subtitle: _isLoggedIn
                  ? '언제 어디서나 간편하게 참여할 수 있는 착한 후원 시스템'
                  : '반갑습니다',
            ),
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

    final myPageScreen = MyPageScreen(
      onLoginTap: _navigateToLogin,
      onSignupTap: _navigateToSignup,
      onLogout: () {
        if (mounted) setState(() => _bottomIndex = 0);
      },
    );

    return [homeScreen, myPageScreen];
  }

  /// BottomNavigationBar의 currentIndex 계산. _isAdmin이 true면 무조건 5탭 구간(0~4) 유지
  int _getBottomNavIndex() {
    if (_isAdmin) {
      return _bottomIndex.clamp(0, 4);
    } else {
      // 일반 유저: 0~2 범위
      return _bottomIndex.clamp(0, 2);
    }
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _phaseStatsReady
                    ? PlatformStatsCard(
                        subtitle: _isLoggedIn
                            ? '언제 어디서나 간편하게 참여할 수 있는 착한 후원 시스템'
                            : '반갑습니다',
                      )
                    : const SizedBox(
                        height: 100,
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
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
    // 로그아웃 후 user가 null인 경우 상태 강제 리셋
    final currentUser = AuthRepository.instance.currentUser;
    debugPrint('🚩 [LOG] MainScreen 빌드됨 - 유저 ID: ${currentUser?.id ?? "null"}, 닉네임: ${currentUser?.nickname ?? "null"}');
    
    if (currentUser == null) {
      debugPrint('🚩 [LOG] MainScreen - 유저가 null임. 상태 리셋 필요');
      // 로그아웃된 상태: 관리자 상태 및 탭 인덱스 리셋
      if (_lastKnownAdmin || _bottomIndex != 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            debugPrint('🚩 [LOG] MainScreen - 상태 리셋 실행: _lastKnownAdmin=false, _bottomIndex=0');
            setState(() {
              _lastKnownAdmin = false;
              _bottomIndex = 0;
            });
          }
        });
      }
    }
    
    final isMobile = ResponsiveHelper.isMobile(context);
    // 모바일 + 홈(0)일 때만 appBar를 비워서, body 내 SliverAppBar(노란 헤더) 하나만 보이게 함. 이중 AppBar 방지.
    final showHeaderInBody = isMobile && _bottomIndex == 0;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미 첫 화면입니다.')),
        );
      },
      child: Scaffold(
        appBar: showHeaderInBody
            ? null
            : CurvedYellowHeader(
                isLoggedIn: _isLoggedIn,
                onPersonTap: _isLoggedIn ? _navigateToProfileEdit : _navigateToLogin,
              ),
        body: IndexedStack(
          index: _getIndexedStackIndex(),
          children: _buildIndexedStackChildren(),
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

