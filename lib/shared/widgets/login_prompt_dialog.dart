// 목적: 비로그인 상태에서 후원/추가/마이페이지 등 클릭 시 로그인·회원가입 유도 다이얼로그.
// 흐름: 다이얼로그에서 로그인/회원가입 탭 시 콜백으로 해당 화면으로 이동.

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// 로그인/회원가입 유도 다이얼로그
class LoginPromptDialog extends StatelessWidget {
  const LoginPromptDialog({
    super.key,
    this.title = '로그인이 필요합니다',
    this.content = '해당 기능을 이용하시려면 로그인 또는 회원가입을 해 주세요.',
    this.onLoginTap,
    this.onSignupTap,
  });

  final String title;
  final String content;
  final VoidCallback? onLoginTap;
  final VoidCallback? onSignupTap;

  static Future<void> show(
    BuildContext context, {
    String? title,
    String? content,
    VoidCallback? onLoginTap,
    VoidCallback? onSignupTap,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => LoginPromptDialog(
        title: title ?? '로그인이 필요합니다',
        content: content ?? '해당 기능을 이용하시려면 로그인 또는 회원가입을 해 주세요.',
        onLoginTap: onLoginTap,
        onSignupTap: onSignupTap,
      ),
    );
  }

  /// 바텀시트 형태로 로그인 유도 (작성 탭 등에서 비로그인 시 사용)
  static Future<void> showAsBottomSheet(
    BuildContext context, {
    String? title,
    String? content,
    VoidCallback? onLoginTap,
    VoidCallback? onSignupTap,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title ?? '로그인이 필요합니다',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                content ?? '해당 기능을 이용하시려면 로그인 또는 회원가입을 해 주세요.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('취소'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onLoginTap?.call();
                      },
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('로그인'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onSignupTap?.call();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.yellow),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('회원가입'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onLoginTap?.call();
          },
          child: const Text('로그인'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onSignupTap?.call();
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.yellow),
          child: const Text('회원가입'),
        ),
      ],
    );
  }
}
