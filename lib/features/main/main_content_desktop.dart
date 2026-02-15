// 목적: 메인 화면 본문 — 웹/데스크톱용 2컬럼 (좌: 피드, 우: 후원자 순위).
// 흐름: MainScreen → ResponsiveLayout desktopChild로 사용.

import 'package:flutter/material.dart';
import '../../../shared/widgets/approved_posts_feed.dart';
import '../../../shared/widgets/donor_rank_list.dart';
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

  static List<({int rank, String name, String amountString})> get _sampleRankList => [
        (rank: 1, name: '도우미 사는 인생 🎗️', amountString: '135,000원'),
        (rank: 2, name: '후쿠후쿠미야자 🍎', amountString: '120,000원'),
        (rank: 3, name: '3월의벚꽃라면 🍜', amountString: '15,000원'),
      ];

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
                    child: DonorRankList(
                      title: '오늘의 베스트 후원자',
                      items: _sampleRankList,
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
            child: DonorRankList(
              title: '오늘의 베스트 후원자',
              items: _sampleRankList,
            ),
          ),
        ),
      ],
    );
  }
}
