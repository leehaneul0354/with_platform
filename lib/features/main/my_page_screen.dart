// 목적: 마이페이지 — UI4.jpg 레이아웃 복원. 상단 산호 헤더·곡선 전환, 소형 프로필, 통계·위드페이 가로 카드, 고객센터 리스트 내 [버그 제보하기].
// 흐름: 하단 네비 3번 탭. 버그 제보는 로그인 시 이용 가능.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/user_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/assets.dart';
import '../../core/constants/firestore_keys.dart';
import '../../core/services/donation_service.dart';
import '../../core/services/with_pay_service.dart';
import 'with_pay_recharge_dialog.dart';
import '../../core/util/birth_date_util.dart';
import '../../shared/widgets/login_prompt_dialog.dart';
import '../../shared/widgets/role_badge.dart';
import '../../shared/widgets/profile_avatar.dart';
import '../../shared/widgets/bug_report_bottom_sheet.dart';
import '../admin/admin_dashboard_screen.dart';
import '../auth/login_screen.dart';
import '../auth/signup_screen.dart';
import 'main_screen.dart';
import 'account_info_screen.dart';
import '../../core/navigation/app_navigator.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({
    super.key,
    this.onLoginTap,
    this.onSignupTap,
    this.onLogout,
  });

  final VoidCallback? onLoginTap;
  final VoidCallback? onSignupTap;
  /// 로그아웃 완료 후 호출 (메인 갱신·탭 전환용)
  final VoidCallback? onLogout;

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  @override
  void initState() {
    super.initState();
    // 실시간 업데이트를 위해 주기적으로 유저 정보 갱신
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshUser();
    });
  }

  Future<void> _refreshUser() async {
    // 로그아웃 중이면 갱신하지 않음 (세션 부활 방지)
    if (AuthRepository.instance.isLoggingOut) {
      debugPrint('🚩 [LOG] MyPageScreen._refreshUser 차단됨 - 로그아웃 진행 중');
      return;
    }
    
    final user = AuthRepository.instance.currentUser;
    if (user != null) {
      await AuthRepository.instance.fetchUserFromFirestore(user.id);
      if (mounted) setState(() {});
    }
  }

  void _handleLoginTap() {
    if (widget.onLoginTap != null) {
      widget.onLoginTap!();
    } else {
      _navigateToLogin();
    }
  }

  void _handleSignupTap() {
    if (widget.onSignupTap != null) {
      widget.onSignupTap!();
    } else {
      _navigateToSignup();
    }
  }

  Future<void> _handleLogout() async {
    debugPrint('🚩 [LOG] 로그아웃 버튼 클릭됨 (MyPageScreen)');
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) {
      debugPrint('🚩 [LOG] 로그아웃 취소됨');
      return;
    }
    
    debugPrint('🚩 [LOG] 로그아웃 확인됨 - AuthRepository.logout() 호출 시작');
    
    // 로그아웃 실행 - 세션 완전히 파괴
    await AuthRepository.instance.logout();
    if (!mounted) return;
    
    debugPrint('🚩 [LOG] AuthRepository.logout() 완료 - 네비게이션 시작');
    
    // 콜백 호출
    widget.onLogout?.call();
    
    // rootNavigator: true를 사용하여 모든 다이얼로그/시트를 포함한 전체 스택을 비우고 MainScreen으로 강제 이동
    if (mounted) {
      debugPrint('🚩 [LOG] Navigator.pushAndRemoveUntil 실행 - rootNavigator: true');
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (route) => false,
      );
      debugPrint('🚩 [LOG] Navigator.pushAndRemoveUntil 완료');
    }
  }

  void _navigateToLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    ).then((_) {
      if (mounted) {
        _refreshUser();
        setState(() {});
      }
    });
  }

  void _navigateToSignup() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SignupScreen(),
      ),
    ).then((_) {
      if (mounted) {
        _refreshUser();
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // CHECK: 페이지 연결성 확인 완료 — 로그인된 유저의 닉네임·역할(환자/후원자)이 즉시 UI에 반영
    final user = AuthRepository.instance.currentUser;
    final isLoggedIn = user != null;
    final isPatient = user?.type == UserType.patient;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context, user, isLoggedIn),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Text(
                  '① 세부 프로필을 입력할 수 있어요.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                _buildStatsSection(),
                _buildDonationEmptyState(context),
                const SizedBox(height: 16),
                _buildWithPayCard(context, user?.id),
                if (isLoggedIn && user != null) ...[
                  const SizedBox(height: 24),
                  _buildRoleSection(context, user!),
                  const SizedBox(height: 24),
                  _buildMyDonationsSection(context, user!.id),
                ],
                const SizedBox(height: 24),
                const Text(
                  '고객센터',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                _buildCustomerCenterList(context, isLoggedIn, isPatient),
                if (isLoggedIn) ...[
                  const SizedBox(height: 24),
                  _LogoutButton(onLogout: _handleLogout),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 상단 산호 배경 + 흰색 곡선 전환 + 소형 프로필 원형·닉네임·역할
  Widget _buildHeader(BuildContext context, UserModel? user, bool isLoggedIn) {
    return Stack(
      children: [
        Container(
          height: 70, // 메인페이지 상단 높이조절 
          width: double.infinity,
          color: AppColors.coral,
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 30,
          child: CustomPaint(
            size: const Size(double.infinity, 48),
            painter: _CurveClipperPainter(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 48, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _profileCircle(context, 56, isFirst: true, user: user),
                  const SizedBox(width: 8),
                  _profileCircle(context, 40, isFirst: false),
                  const SizedBox(width: 8),
                  _profileCircle(context, 40, isFirst: false),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              isLoggedIn ? user!.nickname : '로그인 후 이용해 주세요.',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.edit, size: 16, color: AppColors.textSecondary),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (isLoggedIn) ...[
                        RoleBadge(role: user!.type, size: RoleBadgeSize.medium),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        isLoggedIn ? 'WITH와 함께해요' : '닉네임과 역할이 여기에 표시돼요.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (isLoggedIn && user!.birthDate != null && user.birthDate!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          BirthDateUtil.formatBirthDateForDisplay(user.birthDate),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _profileCircle(BuildContext context, double size, {bool isFirst = false, UserModel? user}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isFirst ? AppColors.yellow.withValues(alpha: 0.3) : AppColors.inactiveBackground,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isFirst && user != null
          ? ProfileAvatar(
              profileImage: user.profileImage,
              radius: size,
            )
          : null,
    );
  }

  /// 후원내역이 비었을 때 시무룩한 마스코트 + "아직 소식이 없어요"
  Widget _buildDonationEmptyState(BuildContext context) {
    const donationCount = 0;
    if (donationCount > 0) return const SizedBox.shrink();
    final maxW = (MediaQuery.sizeOf(context).width * kMaxImageWidthRatio).clamp(72.0, 100.0);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Center(
        child: Column(
          children: [
            SizedBox(
              width: maxW,
              child: Image.asset(
                WithMascots.sad,
                fit: BoxFit.contain,
                errorBuilder: (_, e, st) => Icon(
                  Icons.sentiment_dissatisfied_outlined,
                  size: maxW,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '아직 소식이 없어요',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 후원내역 / 받은편지 / 내 활동 3단
  Widget _buildStatsSection() {
    return Row(
      children: [
        Expanded(
          child: _StatItem(
            icon: Icons.volunteer_activism,
            label: '후원내역',
            count: '0개',
          ),
        ),
        Expanded(
          child: _StatItem(
            icon: Icons.mail_outline,
            label: '받은편지',
            count: '0개',
          ),
        ),
        Expanded(
          child: _StatItem(
            icon: Icons.favorite_border,
            label: '내 활동',
            count: '0개',
          ),
        ),
      ],
    );
  }

  /// 위드페이 가로형 카드 (노란 배경). 로그인 시 실시간 잔액 스트림, 탭 시 충전 다이얼로그.
  Widget _buildWithPayCard(BuildContext context, String? userId) {
    return InkWell(
      onTap: () {
        if (userId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('로그인 후 충전할 수 있습니다.')),
          );
          return;
        }
        showWithPayRechargeDialog(context, userId);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.yellow.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.yellow.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.yellow,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_balance_wallet_outlined, size: 22, color: AppColors.textPrimary),
            ),
            const SizedBox(width: 12),
            const Text(
              '위드페이',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            if (userId == null)
              Text(
                '0원',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.coral,
                ),
              )
            else
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: withPayBalanceStream(userId),
                builder: (context, snapshot) {
                  final balance = balanceFromSnapshot(snapshot.data);
                  return Text(
                    '${_formatWithPayBalance(balance)}원',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.coral,
                    ),
                  );
                },
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  static String _formatWithPayBalance(int value) {
    if (value >= 10000) return '${value ~/ 10000}만';
    return value.toString();
  }

  /// 역할 섹션: 현재 역할 표시 및 viewer인 경우 전환 버튼
  Widget _buildRoleSection(BuildContext context, UserModel user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inactiveBackground),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person_outline,
                size: 20,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              const Text(
                '내 역할',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          RoleBadge(role: user.type, size: RoleBadgeSize.medium),
          if (user.type == UserType.viewer) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.coral.withValues(alpha: 0.08),
                    AppColors.yellow.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.coral.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.favorite,
                        size: 20,
                        color: AppColors.coral,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '따뜻한 나눔을 시작하시겠습니까?',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          softWrap: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _showDonorConversionDialog(context, user),
                      icon: const Icon(Icons.favorite_outline, size: 20),
                      label: const Text('후원자로 가입/전환하기'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.coral,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getRoleColor(UserType type) {
    switch (type) {
      case UserType.viewer:
        return AppColors.textSecondary;
      case UserType.donor:
        return AppColors.coral;
      case UserType.patient:
        return AppColors.yellow;
      case UserType.admin:
        return const Color(0xFF0D1B2A); // 다크 네이비
    }
  }

  IconData _getRoleIcon(UserType type) {
    switch (type) {
      case UserType.viewer:
        return Icons.visibility_outlined;
      case UserType.donor:
        return Icons.favorite_outline;
      case UserType.patient:
        return Icons.medical_services_outlined;
      case UserType.admin:
        return Icons.admin_panel_settings_outlined;
    }
  }

  Future<void> _showDonorConversionDialog(BuildContext context, UserModel user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.favorite, color: AppColors.coral, size: 24),
            const SizedBox(width: 8),
            const Text(
              '후원자로 전환',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '후원자가 되어 환자분들에게 희망을 전달하시겠습니까?',
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.coral.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.coral.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.star, color: AppColors.coral, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '후원자 뱃지와 전용 기능이 활성화됩니다.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.coral,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('후원자로 전환'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      try {
        await FirebaseFirestore.instance
            .collection(FirestoreCollections.users)
            .doc(user.id)
            .update({
          FirestoreUserKeys.role: UserType.donor.name,
          FirestoreUserKeys.type: UserType.donor.name,
        });
        // 현재 유저 정보 갱신
        await AuthRepository.instance.fetchUserFromFirestore(user.id);
        await _refreshUser();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.celebration, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('축하합니다! 이제 WITH의 천사(Angel)가 되셨습니다. ✨'),
                  ),
                ],
              ),
              backgroundColor: AppColors.coral,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('역할 전환에 실패했습니다. 다시 시도해 주세요.')),
          );
        }
      }
    }
  }

  Future<void> _showRoleChangeDialog(BuildContext context, UserModel user, UserType newRole) async {
    final roleName = newRole.label;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$roleName로 전환'),
        content: Text('정말 $roleName 역할로 전환하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: _getRoleColor(newRole),
            ),
            child: const Text('전환'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      try {
        await FirebaseFirestore.instance
            .collection(FirestoreCollections.users)
            .doc(user.id)
            .update({
          FirestoreUserKeys.role: newRole.name,
          FirestoreUserKeys.type: newRole.name,
        });
        // 현재 유저 정보 갱신
        await AuthRepository.instance.fetchUserFromFirestore(user.id);
        await _refreshUser();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$roleName 역할로 전환되었습니다.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('역할 전환에 실패했습니다. 다시 시도해 주세요.')),
          );
        }
      }
    }
  }

  /// 나의 후원 내역 — Firestore donations에서 userId 일치하는 문서 스트림으로 표시
  Widget _buildMyDonationsSection(BuildContext context, String userId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '나의 후원 내역',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: donationsStreamByUser(userId), // Firestore 복합 인덱스: donations (userId, createdAt desc)
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '후원 내역을 불러올 수 없습니다.',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )),
              );
            }
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '아직 후원 내역이 없습니다.',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
              );
            }
            return Column(
              children: docs.map((doc) {
                final d = doc.data();
                final postTitle = d[DonationKeys.postTitle]?.toString() ?? '(사연)';
                final amount = (d[DonationKeys.amount] is int)
                    ? d[DonationKeys.amount] as int
                    : (int.tryParse(d[DonationKeys.amount]?.toString() ?? '0') ?? 0);
                final createdAt = d[DonationKeys.createdAt];
                String dateStr = '-';
                if (createdAt is Timestamp) {
                  final dt = createdAt.toDate();
                  dateStr = '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
                }
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.inactiveBackground.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              postTitle,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dateStr,
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${_formatDonationAmount(amount)}원',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.coral,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  static String _formatDonationAmount(int value) {
    if (value >= 10000) return '${value ~/ 10000}만';
    return value.toString();
  }

  Future<void> _handleWithdrawal(BuildContext context, UserModel user) async {
    // 1차 확인 다이얼로그
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text(
              '회원 탈퇴',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          '정말 WITH 플랫폼을 떠나시겠습니까?\n\n탈퇴 시 후원 내역 및 데이터 복구가 불가능합니다.',
          style: TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('예'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    // 2차 확인: 탈퇴 사유 설문
    final reason = await _showWithdrawalReasonDialog(context);
    if (reason == null || !mounted) return;

    // 최종 탈퇴 처리
    final finalConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '최종 확인',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          '정말 탈퇴하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
          style: TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('최종 탈퇴'),
          ),
        ],
      ),
    );

    if (finalConfirm != true || !mounted) return;

    // 탈퇴 처리
    if (!mounted) return;
    
    // 로딩 다이얼로그 표시 (context 유효성 검사 후)
    BuildContext? dialogContext;
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          dialogContext = ctx;
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      );
    }

    try {
      await AuthRepository.instance.deleteAccount(reason: reason);
      
      // 탈퇴 완료 후 약간의 지연 (상태 동기화 대기)
      await Future.delayed(const Duration(milliseconds: 300));
      
      // GlobalKey를 사용하여 안전하게 로그인 화면으로 리다이렉트
      // context가 유효하지 않아도 작동함
      final navigator = appNavigatorKey.currentState;
      if (navigator != null) {
        // 로딩 다이얼로그 닫기 (context가 유효한 경우에만)
        if (mounted && dialogContext != null) {
          try {
            Navigator.of(dialogContext!, rootNavigator: true).pop();
          } catch (_) {
            // 다이얼로그가 이미 닫혔을 수 있음 (무시)
          }
        }
        
        // 모든 화면 스택 제거하고 로그인 화면으로 이동
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const LoginScreen(),
            settings: const RouteSettings(name: '/login'),
          ),
          (route) => false,
        );
        
        // SnackBar 표시 (GlobalKey의 context 사용)
        if (appNavigatorKey.currentContext != null) {
          final scaffoldMessenger = ScaffoldMessenger.of(appNavigatorKey.currentContext!);
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('회원 탈퇴가 완료되었습니다.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        // Navigator가 없는 경우 (매우 드문 경우) - mounted 체크 후 처리
        if (mounted && dialogContext != null) {
          try {
            Navigator.of(dialogContext!, rootNavigator: true).pop();
          } catch (_) {}
        }
        debugPrint('🚩 [LOG] Navigator Key가 null입니다. 화면 전환 실패');
        
        // Fallback: mounted context로 시도
        if (mounted) {
          try {
            Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => const LoginScreen(),
                settings: const RouteSettings(name: '/login'),
              ),
              (route) => false,
            );
          } catch (e) {
            debugPrint('🚩 [LOG] Fallback 네비게이션도 실패: $e');
          }
        }
      }
    } catch (e, stackTrace) {
      debugPrint('🚩 [LOG] 회원 탈퇴 처리 중 에러: $e');
      debugPrint('🚩 [LOG] 스택 트레이스: $stackTrace');
      
      // 에러 발생 시 로딩 다이얼로그 닫기
      if (mounted && dialogContext != null) {
        try {
          Navigator.of(dialogContext!, rootNavigator: true).pop();
        } catch (_) {
          // 다이얼로그가 이미 닫혔을 수 있음
        }
      }
      
      // 에러 메시지 표시 (GlobalKey 사용)
      final navigator = appNavigatorKey.currentState;
      if (navigator != null && appNavigatorKey.currentContext != null) {
        ScaffoldMessenger.of(appNavigatorKey.currentContext!).showSnackBar(
          SnackBar(
            content: Text('탈퇴 처리 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      } else if (mounted) {
        // Fallback: mounted context 사용
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('탈퇴 처리 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _showWithdrawalReasonDialog(BuildContext context) async {
    String? selectedReason;
    
    return await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            '탈퇴 사유',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '탈퇴 사유를 선택해주세요.',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                _buildReasonOption(
                  '이용이 불편해서',
                  selectedReason == '이용이 불편해서',
                  () => setState(() => selectedReason = '이용이 불편해서'),
                ),
                const SizedBox(height: 8),
                _buildReasonOption(
                  '후원 대상이 부족해서',
                  selectedReason == '후원 대상이 부족해서',
                  () => setState(() => selectedReason = '후원 대상이 부족해서'),
                ),
                const SizedBox(height: 8),
                _buildReasonOption(
                  '개인정보 보호를 위해',
                  selectedReason == '개인정보 보호를 위해',
                  () => setState(() => selectedReason = '개인정보 보호를 위해'),
                ),
                const SizedBox(height: 8),
                _buildReasonOption(
                  '기타',
                  selectedReason == '기타',
                  () => setState(() => selectedReason = '기타'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: selectedReason != null
                  ? () => Navigator.of(ctx).pop(selectedReason)
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.coral,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('확인'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReasonOption(String reason, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.coral.withValues(alpha: 0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.coral : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? AppColors.coral : Colors.grey.shade600,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                reason,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? AppColors.coral : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 고객센터 리스트 — [버그 제보하기] 리스트 아이템 크기로 첫 항목, 강조색 유지. 관리자일 때만 [관리자 시스템] 최상단 노출.
  Widget _buildCustomerCenterList(BuildContext context, bool isLoggedIn, bool isPatient) {
    final user = AuthRepository.instance.currentUser;
    final isAdmin = user?.type == UserType.admin;

    return Column(
      children: [
        if (isAdmin) ...[
          _AdminSystemTile(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
        _BugReportTile(
          onPressed: () => _onBugReportTap(context, isLoggedIn),
        ),
        if (isLoggedIn) ...[
          _WithPayRechargeTile(
            onTap: () {
              final userId = AuthRepository.instance.currentUser?.id;
              if (userId != null) {
                showWithPayRechargeDialog(context, userId);
              }
            },
          ),
          _MenuTile(
            icon: Icons.receipt_long_outlined,
            label: '전자기부금 영수증 발급',
            onTap: () {
              // 추후 전자기부금 영수증 발급 화면 연결
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('준비 중인 기능입니다.')),
              );
            },
          ),
          _MenuTile(
            icon: Icons.account_circle_outlined,
            label: '계정 정보',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AccountInfoScreen()),
              );
            },
          ),
        ],
        _MenuTile(icon: Icons.person_outline, label: '개인정보 수집 및 이용', onTap: () {}),
        _MenuTile(icon: Icons.description_outlined, label: '서비스 이용 약관', onTap: () {}),
        _MenuTile(icon: Icons.code, label: '오픈소스 라이선스', onTap: () {}),
        _MenuTile(icon: Icons.help_outline, label: '자주묻는질문', onTap: () {}),
        _MenuTile(
          icon: Icons.info_outline,
          label: '버전정보 1.0.0',
          trailing: Text(
            '최신버전입니다',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          onTap: () {},
        ),
      ],
    );
  }

  void _onBugReportTap(BuildContext context, bool isLoggedIn) {
    if (!isLoggedIn) {
      LoginPromptDialog.show(
        context,
        title: '로그인이 필요합니다',
        content: '버그 제보를 하시려면 로그인해 주세요.',
        onLoginTap: _handleLoginTap,
        onSignupTap: _handleSignupTap,
      );
      return;
    }
    showBugReportBottomSheet(context);
  }
}

/// 상단 산호 아래 흰색 영역 — 상단이 중앙에서 아래로 내려오는 오목 곡선
class _CurveClipperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, 0)
      ..quadraticBezierTo(size.width * 0.5, 28, 0, 0);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.count,
  });

  final IconData icon;
  final String label;
  final String count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 28, color: AppColors.yellow),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          count,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.coral,
          ),
        ),
      ],
    );
  }
}

/// 관리자 전용 [관리자 시스템] 진입 타일 — 노란색 강조, AdminDashboardScreen으로 이동
class _AdminSystemTile extends StatelessWidget {
  const _AdminSystemTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.yellow.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.admin_panel_settings, size: 24, color: AppColors.textPrimary),
              const SizedBox(width: 12),
              const Text(
                '관리자 시스템',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right, size: 22, color: AppColors.textPrimary),
            ],
          ),
        ),
      ),
    );
  }
}

/// 고객센터 리스트 내 [WITH 페이 충전] — 노란색 강조
class _WithPayRechargeTile extends StatelessWidget {
  const _WithPayRechargeTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.yellow.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.account_balance_wallet, size: 22, color: AppColors.textPrimary),
              const SizedBox(width: 12),
              Text(
                'WITH 페이 충전',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// 고객센터 리스트 내 [버그 제보하기] — 리스트 아이템과 동일 높이, Coral 강조
class _BugReportTile extends StatelessWidget {
  const _BugReportTile({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.coral.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.bug_report_outlined, size: 22, color: AppColors.coral),
              const SizedBox(width: 12),
              Text(
                '버그 제보하기 🛠️',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.coral,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right, size: 20, color: AppColors.coral),
            ],
          ),
        ),
      ),
    );
  }
}

/// 마이페이지 하단 [로그아웃] 버튼. 클릭 시 확인 후 AuthRepository.logout() → 메인(비로그인) 전환.
class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onLogout,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          side: BorderSide(color: AppColors.textSecondary.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('로그아웃'),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      dense: true,
      leading: Icon(icon, size: 22, color: AppColors.textSecondary),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          color: AppColors.textPrimary,
        ),
      ),
      trailing: trailing ?? const Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
      onTap: onTap,
    );
  }
}
