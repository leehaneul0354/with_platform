// 목적: 메인 화면 본문 — 모바일용 단일 컬럼. 피드 탭 시 승인된 사연(ApprovedPostsFeed), 투데이 시 순위·감사편지.
// 흐름: MainScreen → ResponsiveLayout mobileChild로 사용. 투데이 시 DonorRankListFromFirestore + TodayThankYouGrid.

import 'package:flutter/material.dart';
import '../../../shared/widgets/approved_posts_feed.dart';
import '../../../shared/widgets/donor_rank_list.dart';
import '../../../shared/widgets/today_thank_you_grid.dart';

/// 모바일: 투데이/피드 토글에 따라 스크롤 리스트 표시.
class MainContentMobile extends StatelessWidget {
  const MainContentMobile({
    super.key,
    required this.isFeedSelected,
    this.displayNickname,
  });

  final bool isFeedSelected;
  final String? displayNickname;

  @override
  Widget build(BuildContext context) {
    if (isFeedSelected) {
      return const CustomScrollView(
        slivers: [
          ApprovedPostsFeedSliver(),
        ],
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DonorRankListFromFirestore(
            title: '오늘의 베스트 후원자',
            topN: 5,
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '환자들의 감사편지',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const TodayThankYouGrid(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            spacing: 8,
            padding: EdgeInsets.symmetric(horizontal: 16),
          ),
        ],
      ),
    );
  }
}
