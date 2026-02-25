// 목적: WITH 관리자 시스템 - Split View 사이드바 대시보드
// 흐름: 왼쪽 사이드바 카테고리 선택 → 오른쪽 콘텐츠 영역 즉시 교체
// 확장성: 향후 많은 데이터에 대비한 DataTable/ListView 구조

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/user_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/firestore_keys.dart';
import '../../core/services/donation_service.dart';
import '../main/main_screen.dart';
import 'admin_member_detail_screen.dart';
import 'admin_post_approval_section.dart';
import 'admin_donation_management_section.dart';
import 'admin_hospital_management_section.dart';
import 'admin_bug_report_management_section.dart';
import 'admin_post_management_section.dart';

/// 관리자 카테고리 타입
enum AdminCategory {
  dashboard('플랫폼 대시보드', Icons.dashboard_outlined),
  users('사용자 관리', Icons.people_outlined),
  donations('후원 내역 관리', Icons.volunteer_activism_outlined),
  posts('게시글 승인', Icons.article_outlined),
  adminPosts('어드민 게시물 관리 📝', Icons.campaign_outlined),
  hospitals('병원/기관 관리', Icons.local_hospital_outlined),
  bugReports('버그 제보 관리 🛠️', Icons.bug_report);

  const AdminCategory(this.label, this.icon);
  final String label;
  final IconData icon;
}

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  AdminCategory _selectedCategory = AdminCategory.dashboard;
  bool _isInitialized = false; // 스트림 중복 구독 방지 가드

  @override
  void initState() {
    super.initState();
    // 관리자 페이지 진입 시 초기화 지연 (Firestore 스트림 충돌 방지)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    });
  }

  Future<void> _logout() async {
    debugPrint('🚩 [LOG] 로그아웃 버튼 클릭됨 (AdminMainScreen)');
    await AuthRepository.instance.logout();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 권한 체크
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
      body: Row(
        children: [
          // 왼쪽: 사이드바 (카테고리)
          _buildSidebar(),
          // 오른쪽: 콘텐츠 영역
          Expanded(
            child: _buildContentArea(),
          ),
        ],
      ),
    );
  }

  /// 사이드바 위젯
  Widget _buildSidebar() {
    return Container(
      width: 280,
      color: Colors.white,
      child: Column(
        children: [
          // 사이드바 헤더
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.yellow.withValues(alpha: 0.1),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.inactiveBackground,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.admin_panel_settings, color: AppColors.yellow, size: 24),
                const SizedBox(width: 12),
                const Text(
                  '관리 메뉴',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          // 카테고리 리스트
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: AdminCategory.values.map((category) {
                final isSelected = _selectedCategory == category;
                return _CategoryTile(
                  category: category,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() {
                      _selectedCategory = category;
                    });
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// 콘텐츠 영역 위젯
  Widget _buildContentArea() {
    // 초기화 전에는 로딩 표시 (스트림 충돌 방지)
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return Container(
      color: const Color(0xFFF5F5F5),
      child: switch (_selectedCategory) {
        AdminCategory.dashboard => _DashboardContent(),
        AdminCategory.users => _UsersContent(),
        AdminCategory.donations => _DonationsContent(),
        AdminCategory.posts => _PostsContent(),
        AdminCategory.adminPosts => _AdminPostsContent(),
        AdminCategory.hospitals => _HospitalsContent(),
        AdminCategory.bugReports => _BugReportsContent(),
      },
    );
  }
}

/// 카테고리 타일 위젯
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  final AdminCategory category;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.yellow.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: AppColors.yellow, width: 2)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              category.icon,
              color: isSelected ? AppColors.yellow : AppColors.textSecondary,
              size: 22,
            ),
            const SizedBox(width: 12),
            Text(
              category.label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 플랫폼 대시보드 콘텐츠 (순차 스트림 로딩 적용)
class _DashboardContent extends StatefulWidget {
  @override
  State<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<_DashboardContent> {
  bool _statsStreamReady = false; // 첫 번째 스트림 준비 완료 플래그
  bool _usersStreamReady = false; // 두 번째 스트림 준비 완료 플래그

  @override
  void initState() {
    super.initState();
    // 순차 스트림 로딩: 첫 번째 스트림 시작
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        setState(() {
          _statsStreamReady = true;
        });
        // 두 번째 스트림은 첫 번째 스트림 시작 후 400ms 지연
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) {
          setState(() {
            _usersStreamReady = true;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '플랫폼 대시보드',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          // 통계 카드 그리드 (순차 로딩)
          if (!_statsStreamReady)
            const Center(child: CircularProgressIndicator())
          else
            FutureBuilder<({int totalDonation, int totalSupporters})>(
              future: getPlatformStats(),
              builder: (context, statsSnapshot) {
                final totalDonation = statsSnapshot.data?.totalDonation ?? 0;
                final totalSupporters = statsSnapshot.data?.totalSupporters ?? 0;

                if (!_usersStreamReady) {
                  return const Center(child: CircularProgressIndicator());
                }

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection(FirestoreCollections.users)
                      .snapshots(),
                  builder: (context, usersSnapshot) {
                    final totalUsers = usersSnapshot.data?.docs.length ?? 0;
                    final today = DateTime.now();
                    final todayStart = DateTime(today.year, today.month, today.day);
                    
                    // 오늘 가입자 수 계산
                    int todaySignups = 0;
                    if (usersSnapshot.hasData) {
                      for (var doc in usersSnapshot.data!.docs) {
                        final data = doc.data();
                        final createdAt = data[FirestoreUserKeys.createdAt];
                        if (createdAt is Timestamp) {
                          final createdDate = createdAt.toDate();
                          if (createdDate.isAfter(todayStart)) {
                            todaySignups++;
                          }
                        }
                      }
                    }

                    return Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: '총 후원금',
                            value: _formatAmount(totalDonation),
                            icon: Icons.attach_money,
                            color: AppColors.coral,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _StatCard(
                            label: '총 가입자',
                            value: '$totalUsers',
                            icon: Icons.people_outline,
                            color: AppColors.yellow,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _StatCard(
                            label: '오늘 가입자',
                            value: '$todaySignups',
                            icon: Icons.person_add_outlined,
                            color: const Color(0xFF4CAF50),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _StatCard(
                            label: '총 후원자 수',
                            value: '$totalSupporters',
                            icon: Icons.volunteer_activism,
                            color: const Color(0xFF2196F3),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  String _formatAmount(int value) {
    if (value <= 0) return '0원';
    if (value >= 100000000) {
      return '${(value / 100000000).toStringAsFixed(1)}억원';
    }
    if (value >= 10000) {
      return '${(value / 10000).toStringAsFixed(0)}만원';
    }
    return '${value.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원';
  }
}

/// 통계 카드 위젯
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: const TextStyle(
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

/// 사용자 관리 콘텐츠
class _UsersContent extends StatefulWidget {
  @override
  State<_UsersContent> createState() => _UsersContentState();
}

class _UsersContentState extends State<_UsersContent> {
  List<UserModel> _users = [];
  String _selectedFilter = '전체';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
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
          const SnackBar(content: Text('회원 목록을 불러오지 못했습니다.')),
        );
      }
    }
  }

  List<UserModel> get _filteredUsers {
    if (_selectedFilter == '전체') return _users;
    if (_selectedFilter == '후원자') {
      return _users.where((u) => u.type == UserType.donor).toList();
    }
    if (_selectedFilter == '환자') {
      return _users.where((u) => u.type == UserType.patient).toList();
    }
    if (_selectedFilter == 'WITH 정회원') {
      return _users.where((u) => u.email.isEmpty).toList();
    }
    if (_selectedFilter == 'Google 가입') {
      return _users.where((u) => u.email.isNotEmpty).toList();
    }
    return _users;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 헤더
        Container(
          padding: const EdgeInsets.all(24),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '사용자 관리',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Row(
                children: [
                  // 필터 칩
                  Wrap(
                    spacing: 8,
                    children: [
                      _FilterChip(
                        label: '전체',
                        selected: _selectedFilter == '전체',
                        onSelected: () => setState(() => _selectedFilter = '전체'),
                      ),
                      _FilterChip(
                        label: '후원자',
                        selected: _selectedFilter == '후원자',
                        onSelected: () => setState(() => _selectedFilter = '후원자'),
                      ),
                      _FilterChip(
                        label: '환자',
                        selected: _selectedFilter == '환자',
                        onSelected: () => setState(() => _selectedFilter = '환자'),
                      ),
                      _FilterChip(
                        label: 'WITH 정회원',
                        selected: _selectedFilter == 'WITH 정회원',
                        onSelected: () => setState(() => _selectedFilter = 'WITH 정회원'),
                      ),
                      _FilterChip(
                        label: 'Google 가입',
                        selected: _selectedFilter == 'Google 가입',
                        onSelected: () => setState(() => _selectedFilter = 'Google 가입'),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: _loadUsers,
                    icon: const Icon(Icons.refresh),
                    tooltip: '새로고침',
                  ),
                ],
              ),
            ],
          ),
        ),
        // 데이터 테이블
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filteredUsers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: AppColors.textSecondary.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '회원이 없습니다.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      margin: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            AppColors.yellow.withValues(alpha: 0.1),
                          ),
                          columns: const [
                            DataColumn(label: Text('닉네임', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('아이디', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('가입 경로', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('역할', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('마스코트', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('가입일', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('액션', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: _filteredUsers.map((user) {
                            final joinedAt = _formatJoinedAt(user.joinedAt);
                            final signupMethod = user.email.isNotEmpty 
                                ? 'WITH 플랫폼 (Google)' 
                                : 'WITH 정회원(자체 가입)';
                            
                            return DataRow(
                              cells: [
                                DataCell(Text(user.nickname)),
                                DataCell(Text(user.id)),
                                DataCell(Text(signupMethod)),
                                DataCell(_buildRoleBadge(user.type)),
                                DataCell(Text(user.profileImage ?? '기본값')),
                                DataCell(Text(joinedAt)),
                                DataCell(
                                  TextButton(
                                    onPressed: () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => AdminMemberDetailScreen(user: user),
                                        ),
                                      );
                                      if (mounted) _loadUsers();
                                    },
                                    child: const Text('상세보기'),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildRoleBadge(UserType type) {
    Color color;
    switch (type) {
      case UserType.donor:
        color = AppColors.coral;
        break;
      case UserType.patient:
        color = AppColors.yellow;
        break;
      case UserType.viewer:
        color = AppColors.textSecondary;
        break;
      case UserType.admin:
        color = const Color(0xFF0D1B2A);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        type.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  String _formatJoinedAt(String? joinedAt) {
    if (joinedAt == null || joinedAt.isEmpty) return '-';
    try {
      DateTime date;
      if (joinedAt.contains('T')) {
        date = DateTime.parse(joinedAt);
      } else {
        final parts = joinedAt.split('-');
        if (parts.length == 3) {
          date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        } else {
          return joinedAt;
        }
      }
      return '${date.year}. ${date.month.toString().padLeft(2, '0')}. ${date.day.toString().padLeft(2, '0')}.';
    } catch (e) {
      return joinedAt;
    }
  }
}

/// 필터 칩 위젯
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: AppColors.yellow.withValues(alpha: 0.2),
      checkmarkColor: AppColors.yellow,
      labelStyle: TextStyle(
        color: selected ? AppColors.textPrimary : AppColors.textSecondary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}

/// 후원 내역 관리 콘텐츠
class _DonationsContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const AdminDonationManagementSection();
  }
}

/// 게시글 승인 콘텐츠
class _PostsContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const AdminPostApprovalSection();
  }
}

/// 어드민 게시물 관리 콘텐츠 (정부 정책/기업 광고/플랫폼 소식 — 탐색 탭 배너용)
class _AdminPostsContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const AdminPostManagementSection();
  }
}

/// 병원/기관 관리 콘텐츠
class _HospitalsContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const AdminHospitalManagementSection();
  }
}

/// 버그 제보 관리 콘텐츠
class _BugReportsContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const AdminBugReportManagementSection();
  }
}
