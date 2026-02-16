// 목적: 사용자 역할(role)을 나타내는 상태 뱃지 위젯. 마이페이지 및 프로필 수정 페이지에서 공통 사용.
// 흐름: UserType에 따라 다른 스타일의 뱃지를 표시.

import 'package:flutter/material.dart';
import '../../core/auth/user_model.dart';
import '../../core/constants/app_colors.dart';

/// 역할 뱃지 위젯
class RoleBadge extends StatelessWidget {
  const RoleBadge({
    super.key,
    required this.role,
    this.size = RoleBadgeSize.medium,
  });

  final UserType role;
  final RoleBadgeSize size;

  @override
  Widget build(BuildContext context) {
    final config = _getRoleConfig(role);
    final padding = size == RoleBadgeSize.small
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 8);
    final fontSize = size == RoleBadgeSize.small ? 12.0 : 13.0;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: config.borderColor != null
            ? Border.all(color: config.borderColor!, width: 1.5)
            : null,
        boxShadow: config.shadow
            ? [
                BoxShadow(
                  color: config.backgroundColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            config.emoji,
            style: TextStyle(fontSize: fontSize),
          ),
          const SizedBox(width: 6),
          Text(
            config.label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: config.textColor,
            ),
          ),
        ],
      ),
    );
  }

  _RoleConfig _getRoleConfig(UserType role) {
    switch (role) {
      case UserType.viewer:
        return _RoleConfig(
          label: '일반 회원',
          emoji: '👁️',
          backgroundColor: AppColors.inactiveBackground,
          textColor: AppColors.textSecondary,
          borderColor: null,
          shadow: false,
        );
      case UserType.donor:
        return _RoleConfig(
          label: '공식 후원자',
          emoji: '✨',
          backgroundColor: const Color(0xFF0D1B2A), // 다크 네이비
          textColor: const Color(0xFF4CAF50), // 연두색
          borderColor: const Color(0xFF4CAF50),
          shadow: true,
        );
      case UserType.patient:
        return _RoleConfig(
          label: '사연 주인공',
          emoji: '🏥',
          backgroundColor: AppColors.coral.withValues(alpha: 0.15),
          textColor: AppColors.coral,
          borderColor: AppColors.coral,
          shadow: false,
        );
      case UserType.admin:
        return _RoleConfig(
          label: '관리자',
          emoji: '👑',
          backgroundColor: const Color(0xFFFFD700).withValues(alpha: 0.2), // 골드
          textColor: const Color(0xFFB8860B), // 다크 골드
          borderColor: const Color(0xFFFFD700),
          shadow: true,
        );
    }
  }
}

enum RoleBadgeSize { small, medium }

class _RoleConfig {
  final String label;
  final String emoji;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;
  final bool shadow;

  _RoleConfig({
    required this.label,
    required this.emoji,
    required this.backgroundColor,
    required this.textColor,
    this.borderColor,
    this.shadow = false,
  });
}
