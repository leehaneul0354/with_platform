// 목적: 잘못된 경로 접근 또는 데이터 로딩 실패 시 표시할 공통 에러 UI.
// 흐름: onUnknownRoute 또는 에러 시 이 위젯으로 이동 후 [메인으로] 버튼으로 복귀.

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../features/main/main_screen.dart';

/// 공통 에러 페이지 — 메시지와 메인으로 돌아가기 버튼
class AppErrorPage extends StatelessWidget {
  const AppErrorPage({
    super.key,
    this.message = '일시적인 오류가 발생했습니다.',
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const MainScreen()),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.home),
                  label: const Text('메인으로'),
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: onRetry,
                    child: const Text('다시 시도'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 에러 메시지 토스트 공통 헬퍼
void showErrorToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}
