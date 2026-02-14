// 목적: 회원가입 유형 선택(후원자/환자) 후 상세 정보 입력. 이미지 디자인 반영.
// 흐름: 로그인 화면에서 회원가입 링크 또는 LoginPromptDialog에서 진입 → AuthRepository.signUp 후 pop.

import 'package:flutter/material.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/user_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/util/birth_date_util.dart';
import '../../shared/widgets/with_illustration.dart';

// CHECK: 비밀번호 규칙 (4-20자) 적용 완료
const int _signupIdMin = 2;
const int _signupIdMax = 15;
const int _signupPwMin = 4;
const int _signupPwMax = 20; // TODO: 추후 보안성 강화를 위해 복잡도 검사 로직 추가 예정
// CHECK: 생년월일 기반 비밀번호 초기화 로직 적용 완료
const int _birthDateLength = 6; // YYMMDD

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

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  int _step = 0;
  UserType _selectedType = UserType.donor;
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _birthDateController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;
  String? _idError;
  String? _passwordError;
  String? _passwordConfirmError;
  String? _birthDateError;
  String? _errorMessage;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _idController.addListener(_onFieldChanged);
    _passwordController.addListener(_onFieldChanged);
    _passwordConfirmController.addListener(_onFieldChanged);
    _birthDateController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() => setState(() {});

  @override
  void dispose() {
    _idController.removeListener(_onFieldChanged);
    _passwordController.removeListener(_onFieldChanged);
    _passwordConfirmController.removeListener(_onFieldChanged);
    _birthDateController.removeListener(_onFieldChanged);
    _idController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  bool get _isSignupFormValid {
    final id = _idController.text.trim();
    final pw = _passwordController.text;
    final confirm = _passwordConfirmController.text;
    final birth = _birthDateController.text.trim();
    final idOk = id.length >= _signupIdMin && id.length <= _signupIdMax;
    final pwOk = pw.length >= _signupPwMin && pw.length <= _signupPwMax;
    final confirmOk = confirm == pw;
    final birthOk = BirthDateUtil.isValidYymmdd(birth);
    return idOk && pwOk && confirmOk && birthOk;
  }

  Future<void> _submitStep2() async {
    final id = _idController.text.trim();
    final password = _passwordController.text;
    final confirm = _passwordConfirmController.text;
    final birthDate = _birthDateController.text.trim();

    String? idError;
    if (id.isEmpty) {
      idError = '아이디를 입력해 주세요.';
    } else if (id.length < _signupIdMin || id.length > _signupIdMax) {
      idError = '아이디는 2~15자 사이여야 합니다.';
    }

    String? passwordError;
    if (password.isEmpty) {
      passwordError = '비밀번호를 입력해 주세요.';
    } else if (password.length < _signupPwMin) {
      passwordError = '비밀번호가 너무 짧습니다 (최소 4자).';
    } else if (password.length > _signupPwMax) {
      passwordError = '비밀번호는 최대 20자까지 가능합니다.';
    }

    String? passwordConfirmError;
    if (confirm != password) {
      passwordConfirmError = '비밀번호가 일치하지 않습니다.';
    }

    String? birthDateError;
    if (birthDate.isEmpty) {
      birthDateError = '생년월일 6자리를 입력해 주세요 (예: 030504)';
    } else if (!BirthDateUtil.isValidYymmdd(birthDate)) {
      birthDateError = '생년월일 6자리 숫자를 입력해 주세요 (예: 030504). 월(01~12), 일(01~31)이 올바른지 확인해 주세요.';
    }

    setState(() {
      _idError = idError;
      _passwordError = passwordError;
      _passwordConfirmError = passwordConfirmError;
      _birthDateError = birthDateError;
      _errorMessage = null;
    });
    if (idError != null || passwordError != null || passwordConfirmError != null || birthDateError != null) return;

    final birthDateIso = BirthDateUtil.yymmddToIso(birthDate);
    if (birthDateIso == null) {
      setState(() => _birthDateError = '생년월일 형식이 올바르지 않습니다. 6자리(예: 030504)를 입력해 주세요.');
      return;
    }

    setState(() => _loading = true);

    try {
      final users = await AuthRepository.instance.getUsers();
      if (users.any((e) => e.id == id)) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _errorMessage = '이미 사용 중인 아이디입니다.';
        });
        return;
      }

      final user = UserModel(
        id: id,
        password: password,
        nickname: id,
        type: _selectedType,
        birthDate: birthDateIso,
      );
      await AuthRepository.instance.signUp(user);

      if (!mounted) return;
      setState(() => _loading = false);
      // CHECK: 페이지 연결성 확인 완료 — 회원가입 성공 시 pop(true)로 로그인/메인으로 복귀
      Navigator.of(context).pop(true);
    } catch (e, stackTrace) {
      debugPrint('Signup _submitStep2 error: $e');
      debugPrint(stackTrace.toString());
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = '회원가입 중 오류가 발생했습니다. 다시 시도해 주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Stack(
          children: [
            if (_step == 0) _buildStep1() else _buildStep2(),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (_step == 1) {
                    setState(() => _step = 0);
                  } else {
                    Navigator.of(context).pop();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Step 1: 위드에서 어떤 서비스를 이용하고 싶으세요? / 후원자·환자 선택
  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          const WithIllustrationFull(size: 120),
          const SizedBox(height: 24),
          const Text(
            '위드에서 어떤 서비스를 이용하고 싶으세요?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '원하는 회원가입 유형을 선택하세요. 후원자로 가입 후에도 환자로 전환이 가능합니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          _TypeButton(
            firstLine: '환자에게 후원하고 싶다면',
            secondLine: '후원자로 가입 →',
            onTap: () {
              setState(() => _selectedType = UserType.donor);
              setState(() => _step = 1);
            },
          ),
          const SizedBox(height: 12),
          _TypeButton(
            firstLine: '투병일기를 기록하고 싶다면',
            secondLine: '환자로 가입 →',
            onTap: () {
              setState(() => _selectedType = UserType.patient);
              setState(() => _step = 1);
            },
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  /// Step 2: 안녕하세요 :) 위드입니다. / 아이디(2~15자), 비밀번호(4~20자), 비밀번호 확인
  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          const WithIllustrationSimple(size: 100),
          const SizedBox(height: 16),
          const Text(
            '안녕하세요 :)',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const Text(
            '위드입니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _idController,
            decoration: _inputDecoration.copyWith(
              hintText: '아이디 입력 (2~15자)',
              errorText: _idError,
            ),
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            maxLength: _signupPwMax,
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
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ),
          const SizedBox(height: 4),
          _SignupPasswordHint(
            password: _passwordController.text,
            errorText: _passwordError,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordConfirmController,
            obscureText: _obscurePasswordConfirm,
            maxLength: _signupPwMax,
            decoration: _inputDecoration.copyWith(
              hintText: '비밀번호 확인',
              errorText: _passwordConfirmError,
              counterText: '',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePasswordConfirm ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => setState(
                    () => _obscurePasswordConfirm = !_obscurePasswordConfirm),
              ),
            ),
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _birthDateController,
            decoration: _inputDecoration.copyWith(
              hintText: '생년월일 6자리 (예: 030504)',
              errorText: _birthDateError,
              counterText: '',
            ),
            keyboardType: TextInputType.number,
            maxLength: _birthDateLength,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submitStep2(),
          ),
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
              onPressed: (_loading || !_isSignupFormValid) ? null : _submitStep2,
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
                  : const Text('회원가입'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// CHECK: 비밀번호 규칙 (4-20자) 적용 완료 — 실시간 안내 문구
class _SignupPasswordHint extends StatelessWidget {
  const _SignupPasswordHint({required this.password, this.errorText});

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
    } else if (password.length < _signupPwMin) {
      text = '비밀번호가 너무 짧습니다 (최소 4자).';
      isError = true;
    } else if (password.length > _signupPwMax) {
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

/// 유형 선택 버튼: 두 줄 텍스트 + 오른쪽 화살표 (연한 회색, 라운드)
class _TypeButton extends StatelessWidget {
  const _TypeButton({
    required this.firstLine,
    required this.secondLine,
    required this.onTap,
  });

  final String firstLine;
  final String secondLine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.inactiveBackground,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      firstLine,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      secondLine,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
