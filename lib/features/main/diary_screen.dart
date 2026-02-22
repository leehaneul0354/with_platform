// 목적: 작성(Diary) 탭 — 유저 권한별 화면 분기. 기존 PostCreateChoiceScreen(소중한 기록) 디자인 유지.
// 흐름: 환자→투병 다이어리/감사편지/내 게시물 관리, 후원자→후원 중인 환자 목록, 비로그인→로그인 유도 바텀시트.
// 디자인: 연한 핑크 배경(#FFF0F3), 흰색 카드, 노란 앱바, '소중한 기록' 제목.

import 'package:flutter/material.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/user_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/assets.dart';
import '../../shared/widgets/login_prompt_dialog.dart';
import '../../shared/widgets/my_angels_section.dart';
import '../../shared/widgets/safe_image_asset.dart';
import '../post/post_upload_screen.dart';
import 'patient_my_content_screen.dart';
import 'patient_posts_list_screen.dart';
import 'thank_you_post_list_screen.dart';

/// Diary 탭 배경색 — 이미지 3980.jpg 디자인 (연한 핑크)
const Color _kDiaryBackgroundPink = Color(0xFFFFF0F3);

/// 작성 탭 — 환자/후원자/비로그인 권한별 UI 분기
class DiaryScreen extends StatelessWidget {
  const DiaryScreen({
    super.key,
    required this.onLoginTap,
    required this.onSignupTap,
  });

  final VoidCallback onLoginTap;
  final VoidCallback onSignupTap;

  @override
  Widget build(BuildContext context) {
    final user = AuthRepository.instance.currentUser;

    // 비로그인: 로그인 유도 바텀시트 노출용 빈 화면 + 탭 시 바텀시트
    if (user == null) {
      return _DiaryGuestView(
        onLoginTap: onLoginTap,
        onSignupTap: onSignupTap,
      );
    }

    final isPatient = user.type == UserType.patient;
    final isDonor = user.type == UserType.donor || user.type == UserType.viewer;

    // 환자: 투병 다이어리 작성, 감사편지 작성, 내 게시물 관리
    if (isPatient) {
      return _DiaryPatientView();
    }

    // 후원자/일반회원: 내가 후원 중인 환자 목록
    return _DiaryDonorView();
  }
}

/// 비로그인 시 작성 탭 — 로그인 유도 바텀시트
class _DiaryGuestView extends StatefulWidget {
  const _DiaryGuestView({
    required this.onLoginTap,
    required this.onSignupTap,
  });

  final VoidCallback onLoginTap;
  final VoidCallback onSignupTap;

  @override
  State<_DiaryGuestView> createState() => _DiaryGuestViewState();
}

class _DiaryGuestViewState extends State<_DiaryGuestView> {
  /// 사용자가 직접 [로그인 / 회원가입] 버튼을 클릭했을 때만 바텀시트 노출
  void _showLoginSheet() {
    LoginPromptDialog.showAsBottomSheet(
      context,
      title: '로그인이 필요합니다',
      content: '다이어리를 작성하시려면 로그인 또는 회원가입을 해 주세요.',
      onLoginTap: widget.onLoginTap,
      onSignupTap: widget.onSignupTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kDiaryBackgroundPink,
      appBar: AppBar(
        title: const Text('소중한 기록'),
        backgroundColor: AppColors.yellow,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              // 로그인 유도 문구 카드
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.yellow.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    SafeImageAsset(
                      assetPath: WithMascots.withMascot,
                      width: 32,
                      height: 32,
                      fallback: Icon(Icons.favorite, color: AppColors.coral, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        '다이어리 기능을 이용하려면\n로그인이 필요해요',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _showLoginSheet,
                icon: const Icon(Icons.login_outlined),
                label: const Text('로그인 / 회원가입'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.coral,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 환자 전용: 기존 '소중한 기록' UI — 안내바 + 내가 후원 중인 천사들 + 내 게시물 작성(투병 기록/감사 편지)
class _DiaryPatientView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kDiaryBackgroundPink,
      appBar: AppBar(
        title: const Text('소중한 기록'),
        backgroundColor: AppColors.yellow,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              _buildInfoBar(),
              const SizedBox(height: 24),
              MyAngelsSection(
                title: '내가 후원 중인 천사들',
                showSelectionMode: false,
                onPatientSelected: (patientId, patientName) {
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
              const SizedBox(height: 32),
              _buildPatientWritingSection(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.yellow.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.yellow.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          SafeImageAsset(
            assetPath: WithMascots.withMascot,
            width: 32,
            height: 32,
            fallback: Icon(Icons.favorite, color: AppColors.coral, size: 24),
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
    );
  }

  Widget _buildPatientWritingSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.textSecondary.withValues(alpha: 0.2)),
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
              Icon(Icons.edit_note, color: AppColors.primary, size: 24),
              const SizedBox(width: 8),
              const Text(
                '내 게시물 작성',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '환자님만 게시물을 작성할 수 있습니다.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
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
      ),
    );
  }
}

/// 후원자 전용: 기존 '소중한 기록' UI — 안내바 + 내가 후원 중인 천사들(클릭 시 환자 상세 기록 이동)
class _DiaryDonorView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kDiaryBackgroundPink,
      appBar: AppBar(
        title: const Text('소중한 기록'),
        backgroundColor: AppColors.yellow,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.yellow.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.yellow.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    SafeImageAsset(
                      assetPath: WithMascots.withMascot,
                      width: 32,
                      height: 32,
                      fallback: Icon(Icons.favorite, color: AppColors.coral, size: 24),
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
              MyAngelsSection(
                title: '내가 후원 중인 천사들',
                showSelectionMode: false,
                onPatientSelected: (patientId, patientName) {
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
            ],
          ),
        ),
      ),
    );
  }
}

/// 흰색 카드형 버튼 — 이미지 디자인 (연한 핑크 테두리, 구급함/편지 아이콘)
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
            color: Colors.white,
            border: Border.all(color: _kDiaryBackgroundPink, width: 1.5),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
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
