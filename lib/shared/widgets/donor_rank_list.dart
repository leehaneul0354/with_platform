// 목적: 오늘의 베스트 후원자 / 전체 순위 리스트 표시.
// 흐름: 메인 화면 데스크톱 영역(우측) 또는 순위 전체보기 화면에서 사용.
// DonorRankListFromFirestore: donations 스트림 + users에서 닉네임 조회 후 실시간 표시.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/firestore_keys.dart';
import '../../core/services/donation_service.dart';
import 'user_profile_avatar.dart';

/// 후원자 한 명 항목 (순위, 이름, 금액)
class DonorRankItem extends StatelessWidget {
  const DonorRankItem({
    super.key,
    required this.rank,
    required this.name,
    required this.amountString,
    this.userId,
  });

  final int rank;
  final String name;
  final String amountString;
  final String? userId;

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
          userId != null && userId!.isNotEmpty
              ? UserProfileAvatar(
                  userId: userId!,
                  radius: 18,
                )
              : CircleAvatar(
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
  final List<({int rank, String name, String amountString, String? userId})> items;

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
                userId: e.userId,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Firestore donations 실시간 스트림 → userId별 금액 집계 → users에서 닉네임 조회 후 표시
class DonorRankListFromFirestore extends StatefulWidget {
  const DonorRankListFromFirestore({
    super.key,
    this.title = '오늘의 베스트 후원자',
    this.topN = 5,
  });

  final String title;
  final int topN;

  @override
  State<DonorRankListFromFirestore> createState() => _DonorRankListFromFirestoreState();
}

class _DonorRankListFromFirestoreState extends State<DonorRankListFromFirestore> {
  List<({String userId, int totalAmount})> _topDonors = [];
  final Map<String, String> _nicknames = {};

  Future<void> _fetchNicknames(List<String> userIds) async {
    if (userIds.isEmpty) return;
    final map = <String, String>{};
    final firestore = FirebaseFirestore.instance;
    for (final id in userIds) {
      try {
        final snap = await firestore.collection(FirestoreCollections.users).doc(id).get();
        final name = snap.data()?[FirestoreUserKeys.nickname]?.toString() ??
            snap.data()?[FirestoreUserKeys.name]?.toString();
        map[id] = (name?.trim().isNotEmpty == true) ? name! : '익명';
      } catch (_) {
        map[id] = '익명';
      }
    }
    if (mounted) setState(() => _nicknames.addAll(map));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: recentDonationsStream(limit: 80),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            margin: const EdgeInsets.all(16),
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '후원자 목록을 불러올 수 없습니다.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
            ),
          );
        }
        final newTop = topDonorsFromSnapshot(
          snapshot.data!,
          topN: widget.topN,
        );
        final ids = newTop.map((e) => e.userId).toList();
        final needFetch = ids.any((id) => !_nicknames.containsKey(id));
        if (newTop != _topDonors) {
          _topDonors = newTop;
          if (needFetch) _fetchNicknames(ids);
        }

        if (_topDonors.isEmpty) {
          return Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '아직 후원 내역이 없어요',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }

        String formatAmount(int v) {
          if (v >= 10000) return '${(v / 10000).toStringAsFixed(v % 10000 == 0 ? 0 : 1)}만원';
          return '$v원';
        }

        final items = <({int rank, String name, String amountString, String? userId})>[];
        for (var i = 0; i < _topDonors.length; i++) {
          final e = _topDonors[i];
          items.add((
            rank: i + 1,
            name: _nicknames[e.userId] ?? '로딩 중',
            amountString: formatAmount(e.totalAmount),
            userId: e.userId,
          ));
        }

        return DonorRankList(title: widget.title, items: items);
      },
    );
  }
}
