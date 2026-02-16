// 목적: platform_stats 실시간 스트림으로 후원 현황 표시. 없으면 0원.
// 흐름: DonationService.platformStatsStream → MainVisualCard amountString.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/constants/firestore_keys.dart';
import '../../core/services/donation_service.dart';
import '../../widgets/main_visual_card.dart';

/// platform_stats의 totalDonation을 실시간으로 표시하는 핑크 카드. 문서 없으면 0원.
class PlatformStatsCard extends StatelessWidget {
  const PlatformStatsCard({
    super.key,
    this.subtitle = '언제 어디서나 간편하게 참여할 수 있는 착한 후원 시스템',
    this.title = '현재 후원 진행상황',
  });

  final String subtitle;
  final String title;

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
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: platformStatsStream(),
      builder: (context, snapshot) {
        int total = 0;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data();
          final v = data?[PlatformStatsKeys.totalDonation];
          if (v is int) total = v;
          else if (v is num) total = v.toInt();
        }
        final amountString = _formatAmount(total);
        return MainVisualCard(
          amountString: amountString,
          subtitle: subtitle,
          title: title,
        );
      },
    );
  }
}
