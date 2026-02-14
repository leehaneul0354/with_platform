// 목적: 오늘의 베스트 후원자 / 전체 순위 리스트 표시.
// 흐름: 메인 화면 데스크톱 영역(우측) 또는 순위 전체보기 화면에서 사용.

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// 후원자 한 명 항목 (순위, 이름, 금액)
class DonorRankItem extends StatelessWidget {
  const DonorRankItem({
    super.key,
    required this.rank,
    required this.name,
    required this.amountString,
  });

  final int rank;
  final String name;
  final String amountString;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.inactiveBackground,
            child: Text(
              name.isNotEmpty ? name[0] : '?',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(color: AppColors.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(Icons.star_outline, size: 18, color: AppColors.yellow),
          const SizedBox(width: 6),
          Text(
            amountString,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 후원자 순위 목록 (제목 + 항목들)
class DonorRankList extends StatelessWidget {
  const DonorRankList({
    super.key,
    required this.title,
    required this.items,
  });

  final String title;
  final List<({int rank, String name, String amountString})> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ...items.map(
              (e) => DonorRankItem(
                rank: e.rank,
                name: e.name,
                amountString: e.amountString,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
