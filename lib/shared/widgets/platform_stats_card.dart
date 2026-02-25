// 목적: platform_stats 단발 조회로 후원 현황 표시. ca9 방지를 위해 스트림 미사용.
// 흐름: getPlatformStats() 1회 호출 → MainVisualCard amountString.

import 'package:flutter/material.dart';

import '../../core/services/donation_service.dart';
import '../../widgets/main_visual_card.dart';

/// platform_stats의 totalDonation을 단발 조회로 표시. 오류/문서 없으면 0원.
class PlatformStatsCard extends StatefulWidget {
  const PlatformStatsCard({
    super.key,
    this.subtitle = '언제 어디서나 간편하게 참여할 수 있는 착한 후원 시스템',
    this.title = '현재 후원 진행상황',
  });

  final String subtitle;
  final String title;

  @override
  State<PlatformStatsCard> createState() => _PlatformStatsCardState();
}

class _PlatformStatsCardState extends State<PlatformStatsCard> {
  Future<int>? _totalFuture;

  @override
  void initState() {
    super.initState();
    _totalFuture = _loadTotalOnce();
  }

  Future<int> _loadTotalOnce() async {
    final stats = await getPlatformStats();
    return stats.totalDonation;
  }

  static String _formatAmount(int value) {
    if (value <= 0) return '0';
    final s = value.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _totalFuture,
      builder: (context, snapshot) {
        final total = snapshot.data ?? 0;
        final amountString = _formatAmount(total);
        return MainVisualCard(
          amountString: amountString,
          subtitle: widget.subtitle,
          title: widget.title,
        );
      },
    );
  }
}
