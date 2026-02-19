// 목적: 계정 정보 페이지 — 프로필 이미지, 이름, 이메일, 가입일, 후원 횟수, 회원 탈퇴 버튼
// 흐름: 마이페이지 고객센터 → [계정 정보] 클릭 → AccountInfoScreen 진입

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/user_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/assets.dart';
import '../../core/constants/firestore_keys.dart';
import '../../core/services/donation_service.dart';
import '../../shared/widgets/profile_avatar.dart';
import '../auth/login_screen.dart';
import '../../core/navigation/app_navigator.dart';

class AccountInfoScreen extends StatefulWidget {
  const AccountInfoScreen({super.key});

  @override
  State<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends State<AccountInfoScreen> {
  @override
  Widget build(BuildContext context) {
    final user = AuthRepository.instance.currentUser;
    
    if (user == null) {
      // 유저가 없으면 로그인 화면으로 리다이렉트
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          '계정 정보',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 프로필 이미지 및 기본 정보
            _buildProfileSection(user),
            const SizedBox(height: 24),
            
            // 계정 상세 정보 (실시간 Firestore 데이터)
            _buildAccountDetailsSection(user),
            const SizedBox(height: 24),
            
            // 회원 탈퇴 버튼
            _buildWithdrawalButton(user),
          ],
        ),
      ),
    );
  }

  /// 프로필 이미지 및 기본 정보 섹션
  Widget _buildProfileSection(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 프로필 이미지
          ProfileAvatar(
            profileImage: user.profileImage,
            radius: 40,
          ),
          const SizedBox(height: 16),
          // 이름
          Text(
            user.nickname,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          // 이메일
          if (user.email.isNotEmpty)
            Text(
              user.email,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  /// 계정 상세 정보 섹션 (실시간 Firestore 데이터)
  Widget _buildAccountDetailsSection(UserModel user) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(user.id)
          .snapshots(),
      builder: (context, userSnapshot) {
        // Firestore에서 유저 데이터 읽기 (실시간 동기화)
        String joinedAtFormatted = '정보 없음';
        Timestamp? createdAt;
        bool isLoading = userSnapshot.connectionState == ConnectionState.waiting;
        
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          final userData = userSnapshot.data!.data()!;
          
          // createdAt 필드 확인 (여러 가능한 필드명 체크)
          createdAt = userData[FirestoreUserKeys.createdAt] as Timestamp?;
          if (createdAt == null) {
            // joinedAt 필드도 확인
            final joinedAt = userData[FirestoreUserKeys.joinedAt];
            if (joinedAt is Timestamp) {
              createdAt = joinedAt;
            } else if (joinedAt is String && joinedAt.isNotEmpty) {
              try {
                DateTime? date;
                if (joinedAt.contains('T')) {
                  date = DateTime.parse(joinedAt);
                } else {
                  final parts = joinedAt.split('-');
                  if (parts.length == 3) {
                    date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
                  }
                }
                if (date != null) {
                  // 브랜딩 포맷: '2026. 02. 19. WITH와 함께 시작됨'
                  joinedAtFormatted = '${date.year}. ${date.month.toString().padLeft(2, '0')}. ${date.day.toString().padLeft(2, '0')}. WITH와 함께 시작됨';
                }
              } catch (e) {
                debugPrint('🚩 [LOG] AccountInfoScreen - joinedAt 파싱 실패: $e');
              }
            }
          }
          
          if (createdAt != null) {
            final date = createdAt.toDate();
            // 브랜딩 포맷: '2026. 02. 19. WITH와 함께 시작됨'
            joinedAtFormatted = '${date.year}. ${date.month.toString().padLeft(2, '0')}. ${date.day.toString().padLeft(2, '0')}. WITH와 함께 시작됨';
          } else if (joinedAtFormatted == '정보 없음') {
            // createdAt과 joinedAt 모두 null이면 기본값 처리 (오늘 날짜)
            final today = DateTime.now();
            joinedAtFormatted = '${today.year}. ${today.month.toString().padLeft(2, '0')}. ${today.day.toString().padLeft(2, '0')}. WITH와 함께 시작됨';
            debugPrint('🚩 [LOG] AccountInfoScreen - createdAt/joinedAt이 모두 null이므로 오늘 날짜로 표시');
          } else if (joinedAtFormatted != '정보 없음' && !joinedAtFormatted.contains('WITH와 함께 시작됨')) {
            // joinedAt 문자열이 파싱된 경우에도 브랜딩 포맷 적용
            if (joinedAtFormatted.contains('년') && joinedAtFormatted.contains('월') && joinedAtFormatted.contains('일')) {
              // 기존 형식에서 브랜딩 형식으로 변환
              final match = RegExp(r'(\d{4})년 (\d{1,2})월 (\d{1,2})일').firstMatch(joinedAtFormatted);
              if (match != null) {
                final year = match.group(1)!;
                final month = match.group(2)!.padLeft(2, '0');
                final day = match.group(3)!.padLeft(2, '0');
                joinedAtFormatted = '$year. $month. $day. WITH와 함께 시작됨';
              }
            }
          }
        } else if (userSnapshot.hasError) {
          // 에러 발생 시 기존 UserModel 데이터 사용 (Fallback)
          debugPrint('🚩 [LOG] AccountInfoScreen - Firestore 읽기 에러: ${userSnapshot.error}');
          if (user.joinedAt != null && user.joinedAt!.isNotEmpty) {
            try {
              DateTime? date;
              if (user.joinedAt!.contains('T')) {
                date = DateTime.parse(user.joinedAt!);
              } else {
                final parts = user.joinedAt!.split('-');
                if (parts.length == 3) {
                  date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
                }
              }
              if (date != null) {
                // 브랜딩 포맷: '2026. 02. 19. WITH와 함께 시작됨'
                joinedAtFormatted = '${date.year}. ${date.month.toString().padLeft(2, '0')}. ${date.day.toString().padLeft(2, '0')}. WITH와 함께 시작됨';
              } else {
                // 파싱 실패 시 기본값
                final today = DateTime.now();
                joinedAtFormatted = '${today.year}. ${today.month.toString().padLeft(2, '0')}. ${today.day.toString().padLeft(2, '0')}. WITH와 함께 시작됨';
              }
            } catch (e) {
              // 파싱 실패 시 기본값
              final today = DateTime.now();
              joinedAtFormatted = '${today.year}. ${today.month.toString().padLeft(2, '0')}. ${today.day.toString().padLeft(2, '0')}. WITH와 함께 시작됨';
            }
          } else {
            // joinedAt도 없으면 오늘 날짜 (브랜딩 포맷)
            final today = DateTime.now();
            joinedAtFormatted = '${today.year}. ${today.month.toString().padLeft(2, '0')}. ${today.day.toString().padLeft(2, '0')}. WITH와 함께 시작됨';
          }
        } else if (isLoading) {
          // 로딩 중일 때는 기존 데이터 표시 (브랜딩 포맷 적용)
          if (user.joinedAt != null && user.joinedAt!.isNotEmpty) {
            try {
              DateTime? date;
              if (user.joinedAt!.contains('T')) {
                date = DateTime.parse(user.joinedAt!);
              } else {
                final parts = user.joinedAt!.split('-');
                if (parts.length == 3) {
                  date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
                }
              }
              if (date != null) {
                joinedAtFormatted = '${date.year}. ${date.month.toString().padLeft(2, '0')}. ${date.day.toString().padLeft(2, '0')}. WITH와 함께 시작됨';
              } else {
                joinedAtFormatted = user.joinedAt!;
              }
            } catch (e) {
              // 파싱 실패 시 기본값
              final today = DateTime.now();
              joinedAtFormatted = '${today.year}. ${today.month.toString().padLeft(2, '0')}. ${today.day.toString().padLeft(2, '0')}. WITH와 함께 시작됨';
            }
          } else {
            // joinedAt도 없으면 오늘 날짜 (브랜딩 포맷)
            final today = DateTime.now();
            joinedAtFormatted = '${today.year}. ${today.month.toString().padLeft(2, '0')}. ${today.day.toString().padLeft(2, '0')}. WITH와 함께 시작됨';
          }
        }

        // 후원 횟수 (실시간 Firestore 데이터)
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: donationsStreamByUser(user.id),
          builder: (context, donationSnapshot) {
            int totalDonationCount = 0;
            
            if (donationSnapshot.hasData) {
              totalDonationCount = donationSnapshot.data!.docs.length;
            }

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
                      Icon(Icons.account_circle_outlined, size: 20, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      const Text(
                        '계정 정보',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // 가입일
                  _buildInfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: '가입일',
                    value: isLoading ? '로딩 중...' : joinedAtFormatted,
                  ),
                  const SizedBox(height: 16),
                  // 아이디
                  _buildInfoRow(
                    icon: Icons.person_outline,
                    label: '아이디',
                    value: user.id,
                  ),
                  const SizedBox(height: 16),
                  // 가입 경로 (브랜딩)
                  _buildInfoRow(
                    icon: Icons.login_outlined,
                    label: '가입 경로',
                    value: user.email.isNotEmpty 
                        ? 'WITH 플랫폼 (Google)' 
                        : 'WITH 정회원(자체 가입)',
                  ),
                  const SizedBox(height: 16),
                  // 후원 횟수 (실제 DB 카운팅, 명확한 표시)
                  _buildInfoRow(
                    icon: Icons.volunteer_activism_outlined,
                    label: '후원 횟수',
                    value: donationSnapshot.connectionState == ConnectionState.waiting
                        ? '로딩 중...'
                        : donationSnapshot.hasError
                            ? '0회' // 에러 발생 시 0회로 표시
                            : (donationSnapshot.hasData 
                                ? '$totalDonationCount회' 
                                : '0회'), // 데이터 없을 때 명확히 0회 표시
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 정보 행 위젯
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  /// 회원 탈퇴 버튼
  Widget _buildWithdrawalButton(UserModel user) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => _handleWithdrawal(context, user),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text('회원 탈퇴'),
      ),
    );
  }

  /// 회원 탈퇴 처리 (MyPageScreen의 로직 재사용)
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
    
    // 로딩 다이얼로그 표시
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
      
      // 탈퇴 완료 후 약간의 지연
      await Future.delayed(const Duration(milliseconds: 300));
      
      // GlobalKey를 사용하여 안전하게 로그인 화면으로 리다이렉트
      final navigator = appNavigatorKey.currentState;
      if (navigator != null) {
        // 로딩 다이얼로그 닫기
        if (mounted && dialogContext != null) {
          try {
            Navigator.of(dialogContext!, rootNavigator: true).pop();
          } catch (_) {}
        }
        
        // 모든 화면 스택 제거하고 로그인 화면으로 이동
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const LoginScreen(),
            settings: const RouteSettings(name: '/login'),
          ),
          (route) => false,
        );
        
        // SnackBar 표시
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
        // Fallback
        if (mounted && dialogContext != null) {
          try {
            Navigator.of(dialogContext!, rootNavigator: true).pop();
          } catch (_) {}
        }
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
            debugPrint('🚩 [LOG] Fallback 네비게이션 실패: $e');
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
        } catch (_) {}
      }
      
      // 에러 메시지 표시
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('탈퇴 처리 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 탈퇴 사유 다이얼로그
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
}
