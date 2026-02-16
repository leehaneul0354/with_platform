// 목적: 게시글 작성 진입 — 투병 기록 / 감사 편지 중 선택.
// 흐름: 하단 네비 [+] 탭 → 본 화면 → [투병 기록 남기기] → PostUploadScreen / [감사 편지 쓰기] → 내 승인된 사연 목록 → 감사 편지 작성.

import 'package:flutter/material.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/user_model.dart';
import '../../core/constants/app_colors.dart';
import '../admin/admin_dashboard_screen.dart';
import '../post/post_upload_screen.dart';
import 'patient_my_content_screen.dart';
import 'thank_you_post_list_screen.dart';

class PostCreateChoiceScreen extends StatelessWidget {
  const PostCreateChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthRepository.instance.currentUser;
    final isPatient = user?.type == UserType.patient;
    final isAdmin = user?.type == UserType.admin || user?.isAdmin == true;
    
    // patient 또는 admin만 업로드 가능
    if (user == null || (!isPatient && !isAdmin)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('환자 계정 또는 관리자 계정으로 로그인 후 이용할 수 있습니다.'),
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
        title: const Text('게시글 작성'),
        backgroundColor: AppColors.yellow,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              _ChoiceCard(
                icon: Icons.medical_services_outlined,
                iconBg: AppColors.coral.withValues(alpha: 0.2),
                title: '투병 기록 남기기',
                subtitle: '제목, 내용, 사진(0~3장)으로 사연을 등록합니다.',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PostUploadScreen()),
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
                  if (!isPatient) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('환자 계정으로 로그인 후 이용할 수 있습니다.')),
                    );
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ThankYouPostListScreen()),
                  );
                },
              ),
              if (isPatient) ...[
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
