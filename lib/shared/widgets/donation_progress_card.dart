// 목적: UI2 시안 — 현재 후원 금액을 보여주는 코랄 핑크(#FF7E7E) 카드.
// 흐름: 메인 화면 상단. 마스코트(mascot_yellow)가 우측 하단 핑크 박스 안에 배치.

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/assets.dart';

/// UI2 시안 코랄 핑크
const Color _cardCoral = Color(0xFFFF7E7E);

/// 현재 후원 진행상황 카드 (입체감 Stack + 마스코트, mascot_yellow.png 사용)
class DonationProgressCard extends StatelessWidget {
  const DonationProgressCard({
    super.key,
    this.amountString = '2,259,424,122',
    this.subtitle = '언제 어디서나 간편하게 참여할 수 있는 착한 후원 시스템',
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
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.fromLTRB(20, 28, 72, 52),
          decoration: BoxDecoration(
            color: _cardCoral,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
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
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$amountString 원',
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppColors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 12,
          child: SizedBox(
            width: 56,
            height: 56,
            child: Image.asset(
              WithMascots.cardMascot,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                decoration: BoxDecoration(
                  color: AppColors.yellow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.sentiment_satisfied_alt,
                  color: AppColors.textPrimary,
                  size: 32,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
