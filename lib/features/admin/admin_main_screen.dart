// 목적: admin 로그인 시에만 접근 가능한 관리자 대시보드. 회원 현황·통계·상세 진입.
// 흐름: 로그인 분기 또는 앱 기동 시 currentUser.isAdmin이면 진입. 비관리자 접근 시 메인으로 복귀.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/user_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/firestore_keys.dart';
import '../../core/services/donation_service.dart';
import '../main/main_screen.dart';
import 'admin_member_detail_screen.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  List<UserModel> _users = [];
  List<UserModel> _filteredUsers = [];
  bool _loading = true;
  String _selectedFilter = '전체'; // '전체', '후원자', '환자'
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _pendingPostsStream;

  @override
  void initState() {
    super.initState();
    _pendingPostsStream = _firestore
        .collection(FirestoreCollections.posts)
        .where(FirestorePostKeys.status, isEqualTo: FirestorePostKeys.pending)
        .snapshots();
    _loadUsers();
  }

  void _applyFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
      if (filter == '전체') {
        _filteredUsers = _users;
      } else if (filter == '후원자') {
        _filteredUsers = _users.where((u) => u.type == UserType.donor).toList();
      } else if (filter == '환자') {
        _filteredUsers = _users.where((u) => u.type == UserType.patient).toList();
      }
    });
  }

  Future<void> _loadUsers() async {
    await AuthRepository.instance.ensureAuthSync();
    if (!mounted) return;
    try {
      final list = await AuthRepository.instance.getUsers();
      if (mounted) {
        setState(() {
          _users = list;
          _applyFilter(_selectedFilter); // 필터 적용
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
                    // 플랫폼 통계 카드 섹션 (실시간)
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: platformStatsStream(),
                      builder: (context, statsSnapshot) {
                        if (!mounted) return const SizedBox.shrink();
                        
                        int totalDonation = 0;
                        int totalSupporters = 0;
                        
                        if (statsSnapshot.hasData && statsSnapshot.data!.exists) {
                          final data = statsSnapshot.data!.data();
                          totalDonation = (data?[PlatformStatsKeys.totalDonation] as num?)?.toInt() ?? 0;
                          totalSupporters = (data?[PlatformStatsKeys.totalSupporters] as num?)?.toInt() ?? 0;
                        }
                        
                        // 승인 대기 사연 수 조회 (initState에서 1회 생성해 중복 구독 방지)
                        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: _pendingPostsStream,
                          builder: (context, pendingPostsSnapshot) {
                            if (!mounted) return const SizedBox.shrink();
                            
                            int pendingPostsCount = pendingPostsSnapshot.data?.docs.length ?? 0;
                            
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _StatCard(
                                        label: '총 후원금',
                                        value: _formatAmount(totalDonation),
                                        icon: Icons.attach_money,
                                        color: const Color(0xFF0D1B2A),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _StatCard(
                                        label: '총 가입자',
                                        value: '${_users.length}',
                                        icon: Icons.people_outline,
                                        color: const Color(0xFFFF7F7F),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _StatCard(
                                        label: '승인대기 사연',
                                        value: '$pendingPostsCount',
                                        icon: Icons.pending_actions,
                                        color: const Color(0xFFFF9800),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _StatCard(
                                        label: '후원자',
                                        value: '$donorCount',
                                        icon: Icons.favorite_outline,
                                        color: const Color(0xFFFF7F7F),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _StatCard(
                                        label: '환자',
                                        value: '$patientCount',
                                        icon: Icons.medical_services_outlined,
                                        color: const Color(0xFFFFB6C1),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _StatCard(
                                        label: '총 후원자 수',
                                        value: '$totalSupporters',
                                        icon: Icons.volunteer_activism,
                                        color: const Color(0xFFFFD700),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '회원 현황',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D1B2A),
                          ),
                        ),
                        Text(
                          '총 ${_filteredUsers.length}명',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 필터 칩
                    Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('전체'),
                          selected: _selectedFilter == '전체',
                          onSelected: (selected) {
                            if (selected) _applyFilter('전체');
                          },
                          selectedColor: const Color(0xFF0D1B2A).withValues(alpha: 0.1),
                          checkmarkColor: const Color(0xFF0D1B2A),
                        ),
                        FilterChip(
                          label: const Text('후원자'),
                          selected: _selectedFilter == '후원자',
                          onSelected: (selected) {
                            if (selected) _applyFilter('후원자');
                          },
                          selectedColor: const Color(0xFFFF7F7F).withValues(alpha: 0.1),
                          checkmarkColor: const Color(0xFFFF7F7F),
                        ),
                        FilterChip(
                          label: const Text('환자'),
                          selected: _selectedFilter == '환자',
                          onSelected: (selected) {
                            if (selected) _applyFilter('환자');
                          },
                          selectedColor: const Color(0xFFFFB6C1).withValues(alpha: 0.1),
                          checkmarkColor: const Color(0xFFFFB6C1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ..._filteredUsers.map((u) => _MemberListTile(
                          user: u,
                          onTap: () async {
                            if (!mounted) return;
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AdminMemberDetailScreen(user: u),
                              ),
                            );
                            if (mounted) _loadUsers();
                          },
                        )),
                    if (_filteredUsers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 64,
                                color: AppColors.textSecondary.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _selectedFilter == '전체'
                                    ? '가입된 회원이 없습니다.'
                                    : '$_selectedFilter 회원이 없습니다.',
                                style: const TextStyle(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  String _formatAmount(int value) {
    if (value <= 0) return '0원';
    final s = value.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '${buf.toString()}원';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
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
    
    final isPending = user.status == UserStatus.pending;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isPending
              ? const Color(0xFFFF9800).withValues(alpha: 0.3)
              : AppColors.textSecondary.withValues(alpha: 0.1),
          width: isPending ? 2 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user.nickname,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Color(0xFF0D1B2A),
                ),
              ),
            ),
            if (isPending)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '인증 대기',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFF9800),
                  ),
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              _buildInfoChip(
                icon: Icons.person_outline,
                text: user.type.label,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              _buildInfoChip(
                icon: Icons.calendar_today_outlined,
                text: '가입일 $joined',
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
        trailing: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF0D1B2A),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: const Text(
            '상세보기',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: color,
          ),
        ),
      ],
    );
  }

  String _formatDate(String dateStr) {
    try {
      // Timestamp 문자열 형식 처리 (예: "Timestamp(seconds=1737043200, nanoseconds=0)")
      if (dateStr.contains('Timestamp')) {
        final match = RegExp(r'seconds=(\d+)').firstMatch(dateStr);
        if (match != null) {
          final seconds = int.parse(match.group(1)!);
          final date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
          return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
        }
      }
      
      // ISO 형식 (YYYY-MM-DD) 또는 DateTime.parse 가능한 형식
      final d = DateTime.parse(dateStr);
      return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
    } catch (e) {
      // 파싱 실패 시 원문 반환 (디버깅용)
      debugPrint('날짜 포맷팅 에러: $dateStr, $e');
      return dateStr;
    }
  }
}
