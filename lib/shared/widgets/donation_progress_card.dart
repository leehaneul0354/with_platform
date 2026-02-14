// 목적: 현재 후원 금액을 보여주는 분홍색 라운드 카드 (입체감 Stack).
// 흐름: 메인 화면 상단 카드로 사용, 금액은 상수 또는 추후 API 연동. 우측 하단은 반달 마스코트(둥근 정사각형).

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/assets.dart';

/// 현재 후원 진행상황 카드 (입체감용 Stack 포함)
class DonationProgressCard extends StatelessWidget {
  const DonationProgressCard({
    super.key,
    this.amountString = '2,259,424,122',
    this.subtitle = '언제 어디서나 마음을 나눌 수 있는 희망을 전해주세요.',
  });

  final String amountString;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            color: AppColors.coral,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '현재 후원 진행상황',
                style: TextStyle(
                  color: AppColors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$amountString 원',
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppColors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: -12,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                WithMascots.cardMascot,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.yellow,
                  child: const Icon(
                    Icons.sentiment_satisfied_alt,
                    color: AppColors.textPrimary,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
