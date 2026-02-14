// 목적: 메인 화면 본문 — 웹/데스크톱용 2컬럼 (좌: 피드, 우: 후원자 순위).
// 흐름: MainScreen → ResponsiveLayout desktopChild로 사용.

import 'package:flutter/material.dart';
import '../../../shared/widgets/feed_card.dart';
import '../../../shared/widgets/donor_rank_list.dart';
import '../../../shared/widgets/today_feed_toggle.dart';

/// 데스크톱: 좌측 피드/투데이, 우측 순위 리스트. 로그인 시 첫 피드 작성자에 닉네임 표시.
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TodayFeedToggle(
                  isFeedSelected: isFeedSelected,
                  onSelectionChanged: onToggleChanged,
                ),
                if (isFeedSelected) ...[
                  FeedCard(
                    authorName: displayNickname ?? '정현태',
                    likeCount: 333,
                    commentCount: 21,
                    bodyText: '함께 나누는 희망으로 소중한 마음을 전해주세요.',
                  ),
                  const FeedCard(
                    authorName: 'WITH',
                    likeCount: 120,
                    commentCount: 8,
                    bodyText: '오늘도 후원해 주신 분들 감사합니다.',
                  ),
                ] else
                  DonorRankList(
                    title: '오늘의 베스트 후원자',
                    items: _sampleRankList,
                  ),
              ],
            ),
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
