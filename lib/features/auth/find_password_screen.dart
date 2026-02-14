// 목적: 비밀번호 찾기(초기화 시 아이디·생년월일 YYMMDD 입력 후 Firestore에서 조회해 비밀번호를 생년월일로 초기화).
// CHECK: 생년월일 기반 비밀번호 초기화 로직 적용 완료

import 'package:flutter/material.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/constants/app_colors.dart';

const int _birthDateLength = 6;

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

class FindPasswordScreen extends StatefulWidget {
  const FindPasswordScreen({super.key});

  @override
  State<FindPasswordScreen> createState() => _FindPasswordScreenState();
}

class _FindPasswordScreenState extends State<FindPasswordScreen> {
  final _idController = TextEditingController();
  final _birthDateController = TextEditingController();
  String? _idError;
  String? _birthDateError;
  String? _errorMessage;
  bool _loading = false;

  @override
  void dispose() {
    _idController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final id = _idController.text.trim();
    final birthDate = _birthDateController.text.trim();

    String? idError;
    if (id.isEmpty) {
      idError = '아이디를 입력해 주세요.';
    }

    String? birthDateError;
    if (birthDate.isEmpty) {
      birthDateError = '생년월일 6자리를 입력해 주세요. (예: 030504)';
    } else if (birthDate.length != _birthDateLength || !RegExp(r'^\d{6}$').hasMatch(birthDate)) {
      birthDateError = '생년월일 6자리를 입력해 주세요 (예: 030504)';
    }

    setState(() {
      _idError = idError;
      _birthDateError = birthDateError;
      _errorMessage = null;
    });
    if (idError != null || birthDateError != null) return;

    setState(() => _loading = true);
    final ok = await AuthRepository.instance.resetPasswordByIdAndBirthDate(id, birthDate);
    if (!mounted) return;
    setState(() => _loading = false);

    if (ok) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('비밀번호 초기화 완료'),
          content: const Text(
            '비밀번호가 생년월일로 초기화되었습니다. 로그인 후 변경해 주세요.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } else {
      setState(() => _errorMessage = '아이디와 생년월일이 일치하는 회원이 없습니다.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('비밀번호 찾기'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                '가입 시 입력한 아이디와 생년월일(6자리)을 입력하시면\n비밀번호를 생년월일로 초기화합니다.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _idController,
                decoration: _inputDecoration.copyWith(
                  hintText: '아이디',
                  errorText: _idError,
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
                onSubmitted: (_) => _submit(),
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
                  onPressed: _loading ? null : _submit,
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
                      : const Text('비밀번호 초기화'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
