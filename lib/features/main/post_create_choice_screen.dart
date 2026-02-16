// 목적: 게시글 작성 진입 — 투병 기록 / 감사 편지 중 선택.
// 흐름: 하단 네비 [+] 탭 → 본 화면 → [투병 기록 남기기] → PostUploadScreen / [감사 편지 쓰기] → 내 승인된 사연 목록 → 감사 편지 작성.

import 'package:flutter/material.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/user_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/assets.dart';
import '../../shared/widgets/my_angels_section.dart';
import '../admin/admin_dashboard_screen.dart';
import '../post/post_upload_screen.dart';
import 'patient_my_content_screen.dart';
import 'patient_posts_list_screen.dart';
import 'thank_you_post_list_screen.dart';

class PostCreateChoiceScreen extends StatefulWidget {
  const PostCreateChoiceScreen({super.key});

  @override
  State<PostCreateChoiceScreen> createState() => _PostCreateChoiceScreenState();
}

class _PostCreateChoiceScreenState extends State<PostCreateChoiceScreen> {
  String? _selectedTargetId;
  String? _selectedTargetName;

  @override
  Widget build(BuildContext context) {
    final user = AuthRepository.instance.currentUser;
    final isPatient = user?.type == UserType.patient;
    final isAdmin = user?.type == UserType.admin || user?.isAdmin == true;
    
    // 모든 로그인 유저가 접근 가능 (후원자는 기록 확인, 환자는 작성)
    // 비로그인 시에는 접근 제한
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('로그인 후 이용할 수 있습니다.'),
          ),
        );
        Navigator.of(context).pop();
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('소중한 기록'),
        backgroundColor: AppColors.yellow,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              // 가이드 문구
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.yellow.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.yellow.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Image.asset(
                      WithMascots.withMascot,
                      width: 32,
                      height: 32,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.favorite,
                        color: AppColors.coral,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '후원 중인 분들의 소식을 확인해보세요',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // 내가 후원 중인 천사들 섹션
              MyAngelsSection(
                title: '내가 후원 중인 천사들',
                showSelectionMode: false,
                onPatientSelected: (patientId, patientName) {
                  // 환자 카드 클릭 시 기록 목록으로 이동
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PatientPostsListScreen(
                        patientId: patientId,
                        patientName: patientName,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              // 환자 전용 작성 기능 (환자만 보임)
              if (isPatient) ...[
                const Divider(),
                const SizedBox(height: 16),
                const Text(
                  '내 게시물 작성',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _ChoiceCard(
                  icon: Icons.medical_services_outlined,
                  iconBg: AppColors.coral.withValues(alpha: 0.2),
                  title: '투병 기록 남기기',
                  subtitle: '제목, 내용, 사진(0~3장)으로 사연을 등록합니다.',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PostUploadScreen(),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 16),
                _ChoiceCard(
                  icon: Icons.mail_outline,
                  iconBg: AppColors.yellow.withValues(alpha: 0.5),
                  title: '감사 편지 쓰기',
                  subtitle: '승인된 투병 기록에 대한 감사 편지를 작성합니다.',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ThankYouPostListScreen()),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _ChoiceCard(
                  icon: Icons.dashboard_outlined,
                  iconBg: const Color(0xFF0D1B2A).withValues(alpha: 0.1),
                  title: '내 게시물 관리(현황)',
                  subtitle: '작성한 투병 기록과 감사 편지를 확인하고 관리합니다.',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PatientMyContentScreen()),
                    );
                  },
                ),
              ],
              if (isAdmin) ...[
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
                    );
                  },
                  icon: const Icon(Icons.admin_panel_settings_outlined, size: 20),
                  label: const Text('관리자 대시보드'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.textSecondary.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 28, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
