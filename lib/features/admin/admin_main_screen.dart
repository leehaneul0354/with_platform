// 목적: admin 로그인 시에만 접근 가능한 관리자 대시보드. 회원 현황·통계·상세 진입.
// 흐름: 로그인 분기 또는 앱 기동 시 currentUser.isAdmin이면 진입. 비관리자 접근 시 메인으로 복귀.

import 'package:flutter/material.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/user_model.dart';
import '../../core/constants/app_colors.dart';
import '../main/main_screen.dart';
import 'admin_member_detail_screen.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  List<UserModel> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    await AuthRepository.instance.ensureAuthSync();
    if (!mounted) return;
    try {
      final list = await AuthRepository.instance.getUsers();
      if (mounted) {
        setState(() {
          _users = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원 목록을 불러오지 못했습니다. 네트워크를 확인해 주세요.')),
        );
      }
    }
  }

  /// CHECK: 페이지 연결성 확인 완료 — 로그아웃 시 이전 사용자 데이터 제거 후 MainScreen으로 pushAndRemoveUntil
  Future<void> _logout() async {
    await AuthRepository.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // CHECK: 페이지 연결성 확인 완료 — 잘못된 경로(비관리자) 접근 시 메인으로 복귀
    final user = AuthRepository.instance.currentUser;
    if (user == null || !user.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainScreen()),
          (route) => false,
        );
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final donorCount = _users.where((e) => e.type == UserType.donor).length;
    final patientCount = _users.where((e) => e.type == UserType.patient).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'WITH 관리자 시스템',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        actions: [
          TextButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout, size: 20),
            label: const Text('로그아웃'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUsers,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _StatCard(
                          label: '총 회원 수',
                          value: '${_users.length}',
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          label: '후원자',
                          value: '$donorCount',
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          label: '환자',
                          value: '$patientCount',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '회원 현황',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._users.map((u) => _MemberListTile(
                          user: u,
                          onTap: () async {
                            // CHECK: 페이지 연결성 확인 완료 — 회원 목록 → 상세 화면
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AdminMemberDetailScreen(user: u),
                              ),
                            );
                            _loadUsers();
                          },
                        )),
                    if (_users.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            '가입된 회원이 없습니다.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.yellow,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberListTile extends StatelessWidget {
  const _MemberListTile({required this.user, required this.onTap});

  final UserModel user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final joined = user.joinedAt != null
        ? _formatDate(user.joinedAt!)
        : '-';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          user.nickname,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${user.type.label} · 가입일 $joined · ${user.status.label}',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        trailing: TextButton(
          onPressed: onTap,
          child: const Text('상세보기'),
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}
