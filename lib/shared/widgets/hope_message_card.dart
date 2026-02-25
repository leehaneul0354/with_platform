// 목적: 메인 화면 상단 정적 희망 메시지 카드. Firestore/스트림/금액·진행률 없음 → ca9 원인 제거.
// 흐름: MainScreen에서만 사용. 데이터 로드 없이 즉시 렌더.

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

const Color _kCardCoral = Color(0xFFFF7E7E);
const String _kCardMascotAsset = 'assets/images/mascot_yellow.png';

/// 후원 금액·진행률 없이 희망 메시지만 표시. Firestore 통신 없음.
class HopeMessageCard extends StatelessWidget {
  const HopeMessageCard({
    super.key,
    this.message = '오늘도 따뜻한 마음들이 모여 환아들에게 희망의 빛이 되고 있습니다',
  });

  final String message;

  static const double cardHeight = 120.0;
  static const double cardBorderRadius = 32.0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          height: cardHeight,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.fromLTRB(20, 24, 88, 24),
          decoration: BoxDecoration(
            color: _kCardCoral,
            borderRadius: BorderRadius.circular(cardBorderRadius),
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                message,
                style: TextStyle(
                  color: AppColors.white.withValues(alpha: 0.95),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: Padding(
            padding: const EdgeInsets.only(right: 4, bottom: 4),
            child: SizedBox(
              width: 56,
              height: 56,
              child: Image.asset(
                _kCardMascotAsset,
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
        ),
      ],
    );
  }
}
