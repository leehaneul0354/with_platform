// 목적: 앱 기동 시 인증 상태 로드 후 메인 화면으로 전환.
// 흐름: main()에서 Firebase 초기화·loadCurrentUser 완료 후 진입 → ensureAuthSync → MainScreen으로 pushReplacement.

import 'package:flutter/material.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/constants/app_colors.dart';
import '../main/main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await AuthRepository.instance.ensureAuthSync();
      if (!mounted) return;
      try {
        await AuthRepository.instance.seedTestAccountsWithBirthDateIfNeeded();
      } catch (_) {}
      if (!mounted) return;
      _navigateToMain();
    } catch (e) {
      if (!mounted) return;
      // 에러가 나더라도 앱이 죽지 않도록 기본 화면(메인)으로 이동
      _navigateToMain();
    }
  }

  void _navigateToMain() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.yellow,
      body: SafeArea(
        child: Center(
          child: _errorMessage != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          setState(() => _errorMessage = null);
                          _initialize();
                        },
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                )
              : const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'WITH',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 32,
                      ),
                    ),
                    SizedBox(height: 24),
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
