// 목적: 아이디/비밀번호 로그인 폼. 이미지 디자인 반영(일러스트, 문구, 다크 버튼, 하단 링크).
// 흐름: MainScreen 또는 LoginPromptDialog에서 진입 → 성공 시 현재 사용자 저장 후 pop.

import 'package:flutter/material.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/assets.dart';
import '../../core/constants/test_accounts.dart';
import 'find_password_screen.dart';
import 'signup_screen.dart';

// CHECK: 비밀번호 규칙 (4-20자) 적용 완료
const int _idMinLength = 2;
const int _idMaxLength = 15;
const int _pwMinLength = 4;
const int _pwMaxLength = 20; // TODO: 추후 보안성 강화를 위해 복잡도 검사 로직 추가 예정

/// 입력 필드 공통 스타일 (라운드, 연한 회색 테두리)
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

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _idError;
  String? _passwordError;
  String? _errorMessage;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _idController.addListener(_onFieldChanged);
    _passwordController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() => setState(() {});

  @override
  void dispose() {
    _idController.removeListener(_onFieldChanged);
    _passwordController.removeListener(_onFieldChanged);
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isIdValid(String id) {
    final len = id.length;
    return len >= _idMinLength && len <= _idMaxLength;
  }

  bool _isPasswordValid(String id, String password) {
    final len = password.length;
    return len >= _pwMinLength && len <= _pwMaxLength;
  }

  bool get _isFormValid {
    final id = _idController.text.trim();
    final password = _passwordController.text;
    return _isIdValid(id) && _isPasswordValid(id, password);
  }

  Future<void> _submit() async {
    final id = _idController.text.trim();
    final password = _passwordController.text;

    String? idError;
    if (id.isEmpty) {
      idError = '아이디를 입력해 주세요.';
    } else if (id.length < _idMinLength || id.length > _idMaxLength) {
      idError = '아이디는 2~15자 사이여야 합니다.';
    }

    String? passwordError;
    if (password.isEmpty) {
      passwordError = '비밀번호를 입력해 주세요.';
    } else if (password.length < _pwMinLength) {
      passwordError = '비밀번호가 너무 짧습니다 (최소 4자).';
    } else if (password.length > _pwMaxLength) {
      passwordError = '비밀번호는 최대 20자까지 가능합니다.';
    }

    setState(() {
      _idError = idError;
      _passwordError = passwordError;
      _errorMessage = null;
    });
    if (idError != null || passwordError != null) return;

    setState(() => _loading = true);

    final user = await AuthRepository.instance.login(id, password);

    if (!mounted) return;
    setState(() => _loading = false);

    if (user != null) {
      // CHECK: 페이지 연결성 확인 완료 — 로그인 성공 시 pop(true)로 이전 위치(Main)로 복귀
      Navigator.of(context).pop(true);
    } else {
      setState(() => _errorMessage = '아이디 또는 비밀번호가 올바르지 않습니다.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
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
                  _LoginMascotBubble(),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _idController,
                    decoration: _inputDecoration.copyWith(
                      hintText: '아이디 입력 (2~15자)',
                      errorText: _idError,
                    ),
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  ),
                  if (_idError != null) const SizedBox(height: 4),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    maxLength: _pwMaxLength,
                    decoration: _inputDecoration.copyWith(
                      hintText: '비밀번호 입력',
                      errorText: _passwordError,
                      counterText: '',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 4),
                  _LoginPasswordHint(
                    password: _passwordController.text,
                    errorText: _passwordError,
                  ),
                  if (_passwordError != null) const SizedBox(height: 4),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 28),
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
                          : const Text('로그인'),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _bottomLink('아이디 찾기', () {}),
                      const SizedBox(width: 8),
                      _bottomLink('비밀번호 찾기', () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const FindPasswordScreen()),
                        );
                      }),
                      const SizedBox(width: 8),
                      _bottomLink('회원가입', () async {
                        final navigator = Navigator.of(context);
                        final result = await navigator.push<bool>(
                          MaterialPageRoute(
                            builder: (_) => const SignupScreen(),
                          ),
                        );
                        if (result == true && mounted) {
                          navigator.pop(true);
                        }
                      }),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // TODO: [DEV] 테스트용 계정 로직 — 배포 시 제거
                  _TestAccountHint(),
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
    ),
    );
  }

  Widget _bottomLink(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}

/// CHECK: 비밀번호 규칙 (4-20자) 적용 완료 — 실시간 안내 문구
class _LoginPasswordHint extends StatelessWidget {
  const _LoginPasswordHint({required this.password, this.errorText});

  final String password;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    String text;
    bool isError = false;
    if (errorText != null) {
      text = errorText!;
      isError = true;
    } else if (password.isEmpty) {
      text = '비밀번호는 4~20자 사이로 입력해주세요.';
    } else if (password.length < _pwMinLength) {
      text = '비밀번호가 너무 짧습니다 (최소 4자).';
      isError = true;
    } else if (password.length > _pwMaxLength) {
      text = '비밀번호는 최대 20자까지 가능합니다.';
      isError = true;
    } else {
      text = '비밀번호는 4~20자 사이로 입력해주세요.';
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: isError ? Colors.red : AppColors.textSecondary,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}

/// 로그인 상단: mascot1.jpg + 말풍선 "반가워요! 다시 오셨군요" (이미지 가로 30% 이하)
class _LoginMascotBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final maxW = (width * kMaxImageWidthRatio).clamp(80.0, 120.0);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: maxW,
              child: Image.asset(
                WithMascots.login,
                fit: BoxFit.contain,
                errorBuilder: (_, e, st) => Icon(
                  Icons.sentiment_satisfied_alt,
                  size: maxW,
                  color: AppColors.yellow,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '반가워요!\n다시 오셨군요',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 로그인 화면 하단 테스트 계정 안내 (배포 시 제거)
class _TestAccountHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '테스트 계정 (개발용)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '환자: ${TestAccounts.patientId} / ${TestAccounts.patientPw}\n'
            '후원자: ${TestAccounts.sponsorId} / ${TestAccounts.sponsorPw}\n'
            '일반: ${TestAccounts.generalId} / ${TestAccounts.generalPw}\n'
            '관리자: ${TestAccounts.adminId} / ${TestAccounts.adminPw}',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
