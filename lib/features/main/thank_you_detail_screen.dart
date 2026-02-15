// 목적: 투데이 감사 편지 카드 탭 시 상세 내용 표시. 제목·환자명·본문·이미지(또는 플레이스홀더).
// 흐름: TodayThankYouGrid 카드 탭 → 본 화면(풀스크린 또는 모달).

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/firestore_keys.dart';

class ThankYouDetailScreen extends StatelessWidget {
  const ThankYouDetailScreen({
    super.key,
    required this.data,
  });

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final title = data[ThankYouPostKeys.title]?.toString() ?? '(제목 없음)';
    final content = data[ThankYouPostKeys.content]?.toString() ?? '';
    final patientName = data[ThankYouPostKeys.patientName]?.toString() ?? '-';
    final imageUrls = data[ThankYouPostKeys.imageUrls] is List
        ? (data[ThankYouPostKeys.imageUrls] as List).cast<String>()
        : <String>[];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '감사 편지',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.yellow,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '작성자: $patientName',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (imageUrls.isNotEmpty) ...[
              ...imageUrls.map((url) => Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Container(
                              color: AppColors.inactiveBackground,
                              child: const Center(
                                child: SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => _warmPlaceholder(),
                      ),
                    ),
                  )),
              const SizedBox(height: 8),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Text(
                content,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _warmPlaceholder() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.coral.withValues(alpha: 0.2),
            AppColors.yellow.withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(Icons.mail_outline, size: 48, color: AppColors.textSecondary),
      ),
    );
  }
}
