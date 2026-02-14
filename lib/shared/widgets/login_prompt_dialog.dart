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
