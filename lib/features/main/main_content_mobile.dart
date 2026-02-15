// 목적: 메인 화면 본문 — 모바일용 단일 컬럼. 피드 탭 시 승인된 사연(ApprovedPostsFeed), 투데이 시 순위·감사편지.
// 흐름: MainScreen → ResponsiveLayout mobileChild로 사용.

import 'package:flutter/material.dart';
import '../../../shared/widgets/approved_posts_feed.dart';
import '../../../shared/widgets/donor_rank_list.dart';

/// 모바일: 투데이/피드 토글에 따라 스크롤 리스트 표시.
class MainContentMobile extends StatelessWidget {
  const MainContentMobile({
    super.key,
    required this.isFeedSelected,
    this.displayNickname,
  });

  final bool isFeedSelected;
  final String? displayNickname;

  static List<({int rank, String name, String amountString})> get _sampleRankList => [
        (rank: 1, name: '도우미 사는 인생 🎗️', amountString: '135,000원'),
        (rank: 2, name: '후쿠후쿠미야자 🍎', amountString: '120,000원'),
        (rank: 3, name: '3월의벚꽃라면 🍜', amountString: '15,000원'),
      ];

  @override
  Widget build(BuildContext context) {
    if (isFeedSelected) {
      return const ApprovedPostsFeed();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DonorRankList(
            title: '오늘의 베스트 후원자',
            items: _sampleRankList,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '한줄 후기 감사편지',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 160,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _ThanksCard('백혈병 수술비 후원자분들 감사합니다'),
                _ThanksCard('수술비 감사합니다'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThanksCard extends StatelessWidget {
  const _ThanksCard(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE0E0E0),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.bottomLeft,
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF333333),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
