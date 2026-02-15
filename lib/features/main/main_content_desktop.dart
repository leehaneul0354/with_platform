// 목적: 메인 화면 본문 — 웹/데스크톱용 2컬럼 (좌: 피드/투데이, 우: 후원자 순위).
// 흐름: MainScreen → ResponsiveLayout desktopChild로 사용. 투데이 시 실데이터 DonorRankListFromFirestore + TodayThankYouGrid.

import 'package:flutter/material.dart';
import '../../../shared/widgets/approved_posts_feed.dart';
import '../../../shared/widgets/donor_rank_list.dart';
import '../../../shared/widgets/today_thank_you_grid.dart';
import '../../../shared/widgets/today_feed_toggle.dart';

/// 데스크톱: 좌측 피드/투데이, 우측 순위 리스트.
class MainContentDesktop extends StatelessWidget {
  const MainContentDesktop({
    super.key,
    required this.isFeedSelected,
    required this.onToggleChanged,
    this.displayNickname,
  });

  final bool isFeedSelected;
  final ValueChanged<bool> onToggleChanged;
  final String? displayNickname;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TodayFeedToggle(
                  isFeedSelected: isFeedSelected,
                  onSelectionChanged: onToggleChanged,
                ),
              ),
              if (isFeedSelected)
                const Expanded(child: ApprovedPostsFeed())
              else
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const DonorRankListFromFirestore(
                          title: '오늘의 베스트 후원자',
                          topN: 5,
                        ),
                        const SizedBox(height: 20),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 0),
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
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          width: 320,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: const DonorRankListFromFirestore(
              title: '오늘의 베스트 후원자',
              topN: 5,
            ),
          ),
        ),
      ],
    );
  }
}
