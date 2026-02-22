// 목적: 투데이 탭 — 기부 현황 및 감사편지 섹션.
// 흐름: 워터폴 로딩 — streamEnabled 시에만 DonorRankList/TodayThankYouGrid 스트림 활성화.

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/widgets/donor_rank_list.dart';
import '../../shared/widgets/today_thank_you_grid.dart';

/// 투데이 탭 — 실시간 기부 순위 + 베스트 감사편지
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key, this.streamEnabled = false});

  final bool streamEnabled;

  @override
  Widget build(BuildContext context) {
    if (!streamEnabled) {
      return CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.white,
            title: const Text(
              '투데이',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            centerTitle: false,
          ),
          const SliverFillRemaining(
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ],
      );
    }
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          elevation: 0,
          backgroundColor: Colors.white,
          title: const Text(
            '투데이',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          centerTitle: false,
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              '실시간 기부 순위',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 8),
        ),
        SliverToBoxAdapter(
          child: DonorRankListFromFirestore(
            title: '오늘의 베스트 후원자',
            topN: 5,
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 24),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '베스트 감사편지',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 12),
        ),
        SliverToBoxAdapter(
          child: const TodayThankYouGrid(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            spacing: 8,
            padding: EdgeInsets.symmetric(horizontal: 16),
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 24),
        ),
      ],
    );
  }
}
