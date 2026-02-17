// 목적: 회원정보 조회/수정. Firestore 연동 — 아이디(읽기전용), 닉네임·생년월일 수정, 비밀번호 변경(재인증), 로그아웃.
// 흐름: 진입 시 Firestore에서 최신 유저 로드. 저장 시 Firestore update. 비밀번호는 현재 비밀번호 확인 후 변경.

import 'package:flutter/material.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/user_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/assets.dart';
import '../../core/util/birth_date_util.dart';
import '../../shared/widgets/with_header.dart';
import '../../shared/widgets/role_badge.dart';
import '../../shared/widgets/profile_avatar.dart';
import '../../shared/widgets/safe_image_asset.dart';
import 'main_screen.dart';

/// WITH 포인트 컬러 #FFD400
const Color _kYellow = Color(0xFFFFD400);

/// 수정 불가 필드용 회색 배경
const Color _kReadOnlyBg = Color(0xFFE8E8E8);

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key, this.onLogout});

  final VoidCallback? onLogout;

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  UserModel? _user;
  bool _loading = true;
  bool _saving = false;
  bool _changingPassword = false;

  late TextEditingController _nicknameController;
  late TextEditingController _currentPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _newPasswordConfirmController;

  DateTime? _birthDate;
  String? _birthDateError;
  String? _selectedProfileImage;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController();
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _newPasswordConfirmController = TextEditingController();
    _loadUser();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _newPasswordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final u = AuthRepository.instance.currentUser;
    if (u == null) {
      if (mounted) setState(() { _user = null; _loading = false; });
      return;
    }
    final fetched = await AuthRepository.instance.fetchUserFromFirestore(u.id);
    if (!mounted) return;
    setState(() {
      _user = fetched ?? u;
      _loading = false;
      _nicknameController.text = (_user?.nickname ?? '').trim();
      _birthDate = BirthDateUtil.storedToDateTime(_user?.birthDate);
      _selectedProfileImage = _user?.profileImage;
    });
  }

  Future<void> _refreshUser() async {
    final u = _user;
    if (u != null) {
      final fetched = await AuthRepository.instance.fetchUserFromFirestore(u.id);
      if (mounted && fetched != null) {
        setState(() {
          _user = fetched;
          _nicknameController.text = (_user?.nickname ?? '').trim();
          _birthDate = BirthDateUtil.storedToDateTime(_user?.birthDate);
          _selectedProfileImage = _user?.profileImage;
        });
      }
    }
  }

  Future<void> _pickBirthDate() async {
    final initial = _birthDate ?? DateTime(2000, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900, 1, 1),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(primary: _kYellow),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) setState(() { _birthDate = picked; _birthDateError = null; });
  }

  Future<void> _save() async {
    final u = _user;
    if (u == null) return;
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('닉네임을 입력해 주세요.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final birthIso = _birthDate != null ? BirthDateUtil.dateTimeToIso(_birthDate!) : (u.birthDate ?? '');
      final profileImageFileName = _selectedProfileImage != null && _selectedProfileImage!.isNotEmpty
          ? AppAssets.getFileName(_selectedProfileImage!)
          : null;
      // role/type은 항상 AuthRepository.currentUser 기준으로 유지 (관리자 강등 방지)
      final sourceForRole = AuthRepository.instance.currentUser ?? u;
      final updated = sourceForRole.copyWith(
        nickname: nickname,
        birthDate: birthIso.isEmpty ? null : birthIso,
        profileImage: profileImageFileName,
      );
      await AuthRepository.instance.updateUser(updated);
      await AuthRepository.instance.setCurrentUser(updated);
      // Firestore에서 최신 정보 다시 로드하여 역할 변경 등 반영
      await _refreshUser();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('회원 정보가 저장되었습니다.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    final u = _user;
    if (u == null) return;
    final current = _currentPasswordController.text;
    final newPw = _newPasswordController.text;
    final confirm = _newPasswordConfirmController.text;
    if (current.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('현재 비밀번호를 입력해 주세요.')));
      return;
    }
    if (newPw.length < 4 || newPw.length > 20) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('새 비밀번호는 4~20자로 입력해 주세요.')));
      return;
    }
    if (newPw != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('새 비밀번호가 일치하지 않습니다.')));
      return;
    }
    setState(() => _changingPassword = true);
    try {
      final ok = await AuthRepository.instance.updatePasswordReauth(u.id, current, newPw);
      if (!mounted) return;
      if (ok) {
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _newPasswordConfirmController.clear();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('비밀번호가 변경되었습니다.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('현재 비밀번호가 일치하지 않습니다.')));
      }
    } finally {
      if (mounted) setState(() => _changingPassword = false);
    }
  }

  Future<void> _logout() async {
    debugPrint('🚩 [LOG] 로그아웃 버튼 클릭됨 (ProfileEditScreen)');
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃 하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('로그아웃')),
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
    // Navigator.pop()을 호출하지 않고 바로 pushAndRemoveUntil로 모든 스택을 제거
    if (mounted) {
      debugPrint('🚩 [LOG] Navigator.pushAndRemoveUntil 실행 - rootNavigator: true');
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (route) => false,
      );
      debugPrint('🚩 [LOG] Navigator.pushAndRemoveUntil 완료');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: WithHeader(showBackButton: true),
        body: const Center(child: CircularProgressIndicator(color: _kYellow)),
      );
    }
    final u = _user;
    if (u == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: WithHeader(showBackButton: true),
        body: const Center(child: Text('로그인이 필요합니다.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: WithHeader(showBackButton: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: () => _showMascotSelector(),
              child: Center(
                child: Stack(
                  children: [
                    ProfileAvatar(
                      profileImage: _selectedProfileImage,
                      radius: 48,
                      backgroundColor: _kReadOnlyBg,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: _kYellow, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                        child: const Icon(Icons.edit, color: AppColors.textPrimary, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 권한 뱃지
            Center(
              child: RoleBadge(role: u.type, size: RoleBadgeSize.medium),
            ),
            const SizedBox(height: 32),
            _label('아이디 (수정 불가)'),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(color: _kReadOnlyBg, borderRadius: BorderRadius.circular(12)),
              child: Text(u.id, style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
            ),
            const SizedBox(height: 20),
            _label('닉네임'),
            const SizedBox(height: 6),
            TextField(
              controller: _nicknameController,
              decoration: _inputDecoration(hint: '닉네임을 입력하세요'),
            ),
            const SizedBox(height: 20),
            _label('생년월일'),
            const SizedBox(height: 6),
            InkWell(
              onTap: _pickBirthDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text(
                      _birthDate != null ? BirthDateUtil.formatBirthDateForDisplay(BirthDateUtil.dateTimeToIso(_birthDate!)) : '생년월일 선택',
                      style: TextStyle(
                        fontSize: 16,
                        color: _birthDate != null ? AppColors.textPrimary : AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.calendar_today, size: 20, color: _kYellow),
                  ],
                ),
              ),
            ),
            if (_birthDateError != null) ...[
              const SizedBox(height: 4),
              Text(_birthDateError!, style: const TextStyle(fontSize: 12, color: Colors.red)),
            ],
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: _kYellow,
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textPrimary))
                  : const Text('저장하기'),
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _kYellow.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kYellow.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lock_outline, size: 20, color: _kYellow),
                      const SizedBox(width: 8),
                      Text('비밀번호 변경', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _currentPasswordController,
                    obscureText: true,
                    decoration: _inputDecoration(hint: '현재 비밀번호'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _newPasswordController,
                    obscureText: true,
                    decoration: _inputDecoration(hint: '새 비밀번호 (4~20자)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _newPasswordConfirmController,
                    obscureText: true,
                    decoration: _inputDecoration(hint: '새 비밀번호 확인'),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _changingPassword ? null : _changePassword,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kYellow,
                      side: BorderSide(color: _kYellow),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _changingPassword
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('비밀번호 변경'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            OutlinedButton(
              onPressed: _logout,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: BorderSide(color: AppColors.textSecondary.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('로그아웃'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
    );
  }

  InputDecoration _inputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF5F5F5),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  void _showMascotSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _MascotSelectorBottomSheet(
        currentSelection: _selectedProfileImage,
        onSelected: (imagePath) {
          setState(() {
            _selectedProfileImage = imagePath;
          });
          Navigator.of(ctx).pop();
        },
      ),
    );
  }
}

/// 마스코트 선택 바텀시트
class _MascotSelectorBottomSheet extends StatelessWidget {
  const _MascotSelectorBottomSheet({
    required this.currentSelection,
    required this.onSelected,
  });

  final String? currentSelection;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '마스코트 선택',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.0,
              ),
              itemCount: AppAssets.profileMascots.length,
              itemBuilder: (context, index) {
                final mascotPath = AppAssets.profileMascots[index];
                final isSelected = currentSelection == mascotPath;
                return GestureDetector(
                  onTap: () => onSelected(mascotPath),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.grey.shade300,
                        width: isSelected ? 3 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
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
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
