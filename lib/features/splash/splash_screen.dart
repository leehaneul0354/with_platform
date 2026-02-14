// 목적: 앱 기동 시 마스코트 중심 스플래시·로딩 뷰 → 인증 동기화 후 메인으로 전환.
// 흐름: image_48dd69.png + 환영 문구, 데이터 로드 중 mascot_p.png 둥둥 애니메이션 + 로딩 바.

import 'package:flutter/material.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/assets.dart';
import '../main/main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  String? _errorMessage;
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: 0, end: 12).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
    _initialize();
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxImageWidth = screenWidth * kMaxImageWidthRatio;
    final horizontalPadding = MediaQuery.paddingOf(context).horizontal;

    return Scaffold(
      backgroundColor: AppColors.yellow,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20 + horizontalPadding / 2),
          child: _errorMessage != null
              ? _buildErrorState()
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),
                    // 스플래시 중앙 이미지 (가로 30% 이하)
                    SizedBox(
                      width: maxImageWidth.clamp(80.0, 140.0),
                      child: Image.asset(
                        WithMascots.splash,
                        fit: BoxFit.contain,
                        errorBuilder: (_, e, st) => const Icon(
                          Icons.favorite,
                          size: 80,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '함께하는 위드에 오신 걸 환영해요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.35,
                      ),
                    ),
                    const Spacer(),
                    // 로딩: 둥둥 떠다니는 마스코트 + 로딩 바
                    AnimatedBuilder(
                      animation: _floatAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, -_floatAnimation.value),
                          child: child,
                        );
                      },
                      child: SizedBox(
                        width: maxImageWidth.clamp(56.0, 100.0) * 0.8,
                        child: Image.asset(
                          WithMascots.loading,
                          fit: BoxFit.contain,
                          errorBuilder: (_, e, st) => const Icon(
                            Icons.sentiment_satisfied_alt,
                            size: 56,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 160,
                      child: LinearProgressIndicator(
                        backgroundColor: AppColors.textPrimary.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.textPrimary),
                      ),
                    ),
                    const Spacer(flex: 2),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
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
      ),
    );
  }
}
