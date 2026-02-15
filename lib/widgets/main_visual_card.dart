// 목적: 메인·로그인·사용자환경 등 공통 핵심 비주얼 카드. Stack(배경·카드·마스코트) 구조.
// 흐름: 로그인 전/후 동일 레이아웃, amount·userName 등은 생성자로 주입.

import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

/// 메인 비주얼 카드용 마스코트 이미지 경로 (선행 슬래시 없음)
const String _kCardMascotAsset = 'assets/images/mascot_yellow.png';

/// 시안 코랄 핑크
const Color _kCardCoral = Color(0xFFFF7E7E);

/// 메인 화면·로그인 화면 등에서 공통 사용하는 핵심 비주얼 카드.
/// Stack(배경·카드·마스코트), 고정 높이·BorderRadius 32+, 마스코트 우측 하단 Positioned.
class MainVisualCard extends StatelessWidget {
  const MainVisualCard({
    super.key,
    required this.amountString,
    this.subtitle = '언제 어디서나 간편하게 참여할 수 있는 착한 후원 시스템',
    this.title = '현재 후원 진행상황',
  });

  /// 표시할 금액 문자열 (예: "0", "2,259,424,122"). 로그인 전 "0", 로그인 후 Firebase 값.
  final String amountString;

  /// 카드 하단 부가 문구. 로그인 전 "반갑습니다" 등으로 변경 가능.
  final String subtitle;

  /// 카드 상단 제목 문구.
  final String title;

  /// 카드 높이 (시안 기준 220~250)
  static const double cardHeight = 240.0;

  /// 카드 모서리 반경 (32.0 이상)
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
          padding: const EdgeInsets.fromLTRB(20, 28, 88, 28),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
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
                maxLines: 2,
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
