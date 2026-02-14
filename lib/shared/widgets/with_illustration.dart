// 목적: 로그인/회원가입 상단 브랜드 일러스트. 노란 웃는 얼굴 + 주변 도형(선택).
// 흐름: LoginScreen, SignupScreen에서 상단 배치.

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// 풀 버전: 노란 웃는 얼굴 + 파랑/분홍/초록 작은 도형
class WithIllustrationFull extends StatelessWidget {
  const WithIllustrationFull({super.key, this.size = 140});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size + 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 작은 도형들 (배경 겹침)
          Positioned(left: size * 0.1, top: 8, child: _shapeBlue(size * 0.35)),
          Positioned(right: size * 0.05, top: size * 0.15, child: _shapePink(size * 0.3)),
          Positioned(left: size * 0.2, bottom: 24, child: _shapeGreen(size * 0.25)),
          // 메인 노란 웃는 얼굴
          Center(
            child: Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                color: AppColors.yellow,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.sentiment_satisfied_alt,
                size: 80,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shapeBlue(double s) {
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        color: const Color(0xFFB3E5FC),
        borderRadius: BorderRadius.circular(s / 2),
      ),
    );
  }

  Widget _shapePink(double s) {
    return Container(
      width: s,
      height: s * 0.8,
      decoration: BoxDecoration(
        color: const Color(0xFFFFCDD2),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _shapeGreen(double s) {
    return CustomPaint(
      size: Size(s, s),
      painter: _TrianglePainter(const Color(0xFFC8E6C9)),
    );
  }
}

/// 간단 버전: 노란 웃는 얼굴만 (회원가입 상세 단계)
class WithIllustrationSimple extends StatelessWidget {
  const WithIllustrationSimple({super.key, this.size = 100});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size + 24,
      child: Center(
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: AppColors.yellow,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.sentiment_satisfied_alt,
            size: 56,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  _TrianglePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    final path = Path()
      ..moveTo(size.width * 0.5, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
