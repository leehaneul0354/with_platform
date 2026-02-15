// 목적: '피드' / '투데이' 전환 토글. UI2 시안 — 선택된 탭 하단 말풍선 꼬리.
// 흐름: 메인 화면에서 선택값에 따라 본문 콘텐츠 전환. 피드(좌) / 투데이(우).

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// UI2 시안 코랄 핑크 (선택된 탭용)
const Color _toggleCoral = Color(0xFFFF7E7E);

/// 피드 / 투데이 선택 토글 (피드 좌측, 투데이 우측, 말풍선 꼬리)
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ToggleButton(
            label: '피드',
            isSelected: isFeedSelected,
            onTap: () => onSelectionChanged(true),
          ),
          const SizedBox(width: 12),
          _ToggleButton(
            label: '투데이',
            isSelected: !isFeedSelected,
            onTap: () => onSelectionChanged(false),
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
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: isSelected ? _toggleCoral : AppColors.inactiveBackground,
                borderRadius: BorderRadius.circular(24),
              ),
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
            SizedBox(
              height: 10,
              child: isSelected
                  ? CustomPaint(
                      size: const Size(20, 10),
                      painter: _BubbleTailPainter(color: _toggleCoral),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

/// 선택된 탭 하단 말풍선 꼬리 (위쪽 삼각형)
class _BubbleTailPainter extends CustomPainter {
  const _BubbleTailPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(size.width * 0.5 - 6, 0)
      ..lineTo(size.width * 0.5, size.height)
      ..lineTo(size.width * 0.5 + 6, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
