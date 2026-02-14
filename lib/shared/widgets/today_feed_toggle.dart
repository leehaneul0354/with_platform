// 목적: '투데이' / '피드' 전환 토글 버튼.
// 흐름: 메인 화면에서 선택값에 따라 본문 콘텐츠 전환.

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// 투데이 / 피드 선택 토글
class TodayFeedToggle extends StatelessWidget {
  const TodayFeedToggle({
    super.key,
    required this.isFeedSelected,
    required this.onSelectionChanged,
  });

  /// true: 피드 선택, false: 투데이 선택
  final bool isFeedSelected;
  final ValueChanged<bool> onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ToggleButton(
            label: '투데이',
            isSelected: !isFeedSelected,
            onTap: () => onSelectionChanged(false),
          ),
          const SizedBox(width: 12),
          _ToggleButton(
            label: '피드',
            isSelected: isFeedSelected,
            onTap: () => onSelectionChanged(true),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.coral : AppColors.inactiveBackground,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.white : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
