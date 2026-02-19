// 목적: 구글 로그인 후 신규 유저 또는 필수 정보 누락 유저의 추가 정보 입력 화면
// 흐름: 구글 로그인 성공 → 필수 정보 확인 → 정보 누락 시 이 화면으로 리다이렉트 → 정보 입력 후 저장 → 메인 화면으로 이동

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/user_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/assets.dart';
import '../../core/util/birth_date_util.dart';
import '../../shared/widgets/profile_avatar.dart';
import '../../shared/widgets/safe_image_asset.dart';
import '../main/main_screen.dart';

/// 입력 필드 공통 스타일
final _inputDecoration = InputDecoration(
  hintText: '',
  filled: true,
  fillColor: Colors.white,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: AppColors.textSecondary, width: 1.5),
  ),
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
);

class AdditionalInfoScreen extends StatefulWidget {
  const AdditionalInfoScreen({super.key});

  @override
  State<AdditionalInfoScreen> createState() => _AdditionalInfoScreenState();
}

class _AdditionalInfoScreenState extends State<AdditionalInfoScreen> {
  DateTime? _selectedBirthDate;
  UserType? _selectedUserType;
  String? _selectedProfileImage;
  String? _birthDateError;
  String? _userTypeError;
  String? _errorMessage;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // 기본 프로필 이미지를 초기값으로 설정
    _selectedProfileImage = AppAssets.defaultProfile;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  // 안내 문구
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.yellow.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '환영합니다!',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'WITH 플랫폼을 이용하기 위해\n추가 정보를 입력해주세요.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // 생년월일 선택
                  Text(
                    '생년월일',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _selectBirthDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _birthDateError != null
                              ? Colors.red
                              : const Color(0xFFE0E0E0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedBirthDate != null
                                  ? DateFormat('yyyy년 MM월 dd일').format(_selectedBirthDate!)
                                  : '생년월일을 선택해주세요',
                              style: TextStyle(
                                fontSize: 14,
                                color: _selectedBirthDate != null
                                    ? AppColors.textPrimary
                                    : Colors.grey.shade400,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.calendar_today,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_birthDateError != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _birthDateError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // 프로필 이미지 선택
                  Text(
                    '프로필 이미지',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildProfileImageSelector(),
                  const SizedBox(height: 24),
                  // 회원 유형 선택
                  Text(
                    '회원 유형',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildUserTypeSelector(),
                  if (_userTypeError != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _userTypeError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (_loading || !_isFormValid) ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.buttonDark,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('완료'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserTypeSelector() {
    return Column(
      children: [
        _buildUserTypeOption(
          UserType.patient,
          '환자',
          '투병 기록을 남기고 후원을 받을 수 있습니다',
          Icons.local_hospital,
        ),
        const SizedBox(height: 12),
        _buildUserTypeOption(
          UserType.donor,
          '후원자',
          '환자들을 후원하고 응원할 수 있습니다',
          Icons.favorite,
        ),
        const SizedBox(height: 12),
        _buildUserTypeOption(
          UserType.viewer,
          '일반회원',
          '게시글을 조회하고 댓글을 남길 수 있습니다',
          Icons.person_outline,
        ),
      ],
    );
  }

  Widget _buildUserTypeOption(
    UserType type,
    String label,
    String description,
    IconData icon,
  ) {
    final isSelected = _selectedUserType == type;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedUserType = type;
          _userTypeError = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.coral
                : (_userTypeError != null ? Colors.red : const Color(0xFFE0E0E0)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.coral.withValues(alpha: 0.1)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.coral : Colors.grey.shade600,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppColors.coral : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: AppColors.coral,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  bool get _isFormValid {
    return _selectedBirthDate != null && _selectedUserType != null;
  }

  Widget _buildProfileImageSelector() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: AppAssets.profileMascots.length,
        itemBuilder: (context, index) {
          final mascotPath = AppAssets.profileMascots[index];
          final isSelected = _selectedProfileImage == mascotPath;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedProfileImage = mascotPath;
              });
            },
            child: Container(
              width: 80,
              height: 80,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppColors.coral : const Color(0xFFE0E0E0),
                  width: isSelected ? 3 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.coral.withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: SafeImageAsset(
                  assetPath: mascotPath,
                  fit: BoxFit.contain,
                  fallback: Icon(
                    Icons.face,
                    size: 50,
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _selectBirthDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 100);
    final lastDate = now;

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime(now.year - 20),
      firstDate: firstDate,
      lastDate: lastDate,
      locale: const Locale('ko', 'KR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.coral,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedBirthDate = picked;
        _birthDateError = null;
      });
    }
  }

  Future<void> _submit() async {
    // 유효성 검사
    String? birthDateError;
    if (_selectedBirthDate == null) {
      birthDateError = '생년월일을 선택해주세요';
    }

    String? userTypeError;
    if (_selectedUserType == null) {
      userTypeError = '회원 유형을 선택해주세요';
    }

    setState(() {
      _birthDateError = birthDateError;
      _userTypeError = userTypeError;
      _errorMessage = null;
    });

    if (birthDateError != null || userTypeError != null) {
      return;
    }

    setState(() => _loading = true);

    try {
      final currentUser = AuthRepository.instance.currentUser;
      if (currentUser == null) {
        throw Exception('로그인 정보를 찾을 수 없습니다');
      }

      // 생년월일을 YYYY-MM-DD 형식으로 변환
      final birthDateIso = DateFormat('yyyy-MM-dd').format(_selectedBirthDate!);

      // 프로필 이미지 파일명 추출 (전체 경로에서 파일명만)
      final profileImageFileName = _selectedProfileImage != null && _selectedProfileImage!.isNotEmpty
          ? AppAssets.getFileName(_selectedProfileImage!)
          : AppAssets.getFileName(AppAssets.defaultProfile); // 기본값 사용

      // Firestore 업데이트
      await AuthRepository.instance.updateUserOnboardingInfo(
        userId: currentUser.id,
        birthDate: birthDateIso,
        userType: _selectedUserType!,
        profileImage: profileImageFileName,
      );

      // 현재 유저 정보 갱신
      await AuthRepository.instance.fetchUserFromFirestore(currentUser.id);

      if (!mounted) return;
      setState(() => _loading = false);

      // 약간의 지연을 추가하여 UI 업데이트 완료 대기 (부드러운 전환)
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;

      // 메인 화면으로 이동 (모든 화면 스택 제거, 부드러운 전환)
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const MainScreen(),
          settings: const RouteSettings(name: '/main'),
        ),
        (route) => false,
      );
    } catch (e, stackTrace) {
      debugPrint('🚩 [LOG] 추가 정보 저장 실패 - $e');
      debugPrint('🚩 [LOG] 스택 트레이스: $stackTrace');
      
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = '정보 저장 중 오류가 발생했습니다. 다시 시도해주세요.';
      });
    }
  }
}
