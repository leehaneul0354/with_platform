// 목적: 마이페이지 — UI4.jpg 레이아웃 복원. 상단 산호 헤더·곡선 전환, 소형 프로필, 통계·위드페이 가로 카드, 고객센터 리스트 내 [후원 신청하기].
// 흐름: 하단 네비 3번 탭. 후원 신청하기 권한 로직(비로그인/후원자/환자) 유지.

import 'package:flutter/material.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/user_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/assets.dart';
import '../../core/util/birth_date_util.dart';
import '../../shared/widgets/login_prompt_dialog.dart';
import '../admin/admin_dashboard_screen.dart';
import 'donation_request_screen.dart';

class MyPageScreen extends StatelessWidget {
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
                _buildWithPayCard(),
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
                  _LogoutButton(onLogout: onLogout),
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
                      const SizedBox(height: 4),
                      Text(
                        isLoggedIn ? '${user!.type.label} · WITH와 함께해요' : '닉네임과 역할이 여기에 표시돼요.',
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
      child: isFirst
          ? ClipOval(
              child: Image.asset(
                WithMascots.profileDefault,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.sentiment_satisfied_alt,
                  color: AppColors.textPrimary,
                  size: 32,
                ),
              ),
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

  /// 위드페이 가로형 카드 (노란 배경)
  Widget _buildWithPayCard() {
    return Container(
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
          Text(
            '0원',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.coral,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
        ],
      ),
    );
  }

  /// 고객센터 리스트 — [후원 신청하기] 리스트 아이템 크기로 첫 항목, 강조색 유지. 관리자일 때만 [관리자 시스템] 최상단 노출.
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
        _DonationApplyTile(
          onPressed: () => _onDonationApplyTap(context, isLoggedIn, isPatient),
        ),
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

  void _onDonationApplyTap(BuildContext context, bool isLoggedIn, bool isPatient) {
    if (!isLoggedIn) {
      LoginPromptDialog.show(
        context,
        title: '로그인이 필요합니다',
        content: '후원 신청을 하시려면 로그인해 주세요.',
        onLoginTap: onLoginTap,
        onSignupTap: onSignupTap,
      );
      return;
    }
    if (!isPatient) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('안내'),
          content: const Text('환자 전용 기능입니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      return;
    }
    // CHECK: 페이지 연결성 확인 완료 — 마이페이지 [후원 신청하기] → 신청 폼 화면
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const DonationRequestScreen(),
      ),
    );
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

/// 고객센터 리스트 내 [후원 신청하기] — 리스트 아이템과 동일 높이, Coral/Yellow 강조
class _DonationApplyTile extends StatelessWidget {
  const _DonationApplyTile({required this.onPressed});

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
              Icon(Icons.volunteer_activism, size: 22, color: AppColors.coral),
              const SizedBox(width: 12),
              Text(
                '후원 신청하기',
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
  const _LogoutButton({this.onLogout});

  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => _handleLogout(context),
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

  Future<void> _handleLogout(BuildContext context) async {
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
    if (confirm != true || !context.mounted) return;
    await AuthRepository.instance.logout();
    if (!context.mounted) return;
    onLogout?.call();
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
