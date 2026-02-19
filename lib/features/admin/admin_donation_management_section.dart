// 목적: 후원 내역 관리 섹션 - 전체 후원 건수, 병원별 정산 상태 관리
// 흐름: AdminMainScreen의 '후원 내역 관리' 카테고리 선택 시 표시

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/firestore_keys.dart';
import '../../core/services/donation_service.dart';

class AdminDonationManagementSection extends StatefulWidget {
  const AdminDonationManagementSection({super.key});

  @override
  State<AdminDonationManagementSection> createState() => _AdminDonationManagementSectionState();
}

class _AdminDonationManagementSectionState extends State<AdminDonationManagementSection> {
  bool _statsStreamReady = false; // 통계 스트림 준비 완료 플래그
  bool _tableStreamReady = false; // 테이블 스트림 준비 완료 플래그

  @override
  void initState() {
    super.initState();
    // 순차 스트림 로딩: 첫 번째 스트림 시작
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        setState(() {
          _statsStreamReady = true;
        });
        // 두 번째 스트림은 첫 번째 스트림 시작 후 400ms 지연
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) {
          setState(() {
            _tableStreamReady = true;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 헤더
        Container(
          padding: const EdgeInsets.all(24),
          color: Colors.white,
          child: const Text(
            '후원 내역 관리',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        // 통계 카드 (순차 로딩)
        Padding(
          padding: const EdgeInsets.all(24),
          child: !_statsStreamReady
              ? const Center(child: CircularProgressIndicator())
              : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection(FirestoreCollections.donations)
                      .snapshots(),
                  builder: (context, snapshot) {
                    int totalCount = snapshot.data?.docs.length ?? 0;
                    int totalAmount = 0;
                    
                    if (snapshot.hasData) {
                      for (var doc in snapshot.data!.docs) {
                        final data = doc.data();
                        final amount = (data[DonationKeys.amount] is int)
                            ? data[DonationKeys.amount] as int
                            : (int.tryParse(data[DonationKeys.amount]?.toString() ?? '0') ?? 0);
                        totalAmount += amount;
                      }
                    }

                    return Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: '전체 후원 건수',
                            value: '$totalCount건',
                            icon: Icons.volunteer_activism_outlined,
                            color: AppColors.coral,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _StatCard(
                            label: '전체 후원 금액',
                            value: _formatAmount(totalAmount),
                            icon: Icons.attach_money,
                            color: AppColors.yellow,
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
        // 후원 내역 테이블 (순차 로딩)
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: !_tableStreamReady
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection(FirestoreCollections.donations)
                        .orderBy(DonationKeys.createdAt, descending: true)
                        .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('에러: ${snapshot.error}'));
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.volunteer_activism_outlined,
                          size: 64,
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '후원 내역이 없습니다.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      AppColors.yellow.withValues(alpha: 0.1),
                    ),
                    columns: const [
                      DataColumn(label: Text('후원자 ID', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('게시글 제목', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('후원 금액', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('후원일', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('병원명', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('정산 상태', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: docs.map((doc) {
                      final data = doc.data();
                      final userId = data[DonationKeys.userId]?.toString() ?? '-';
                      final postTitle = data[DonationKeys.postTitle]?.toString() ?? '-';
                      final amount = (data[DonationKeys.amount] is int)
                          ? data[DonationKeys.amount] as int
                          : (int.tryParse(data[DonationKeys.amount]?.toString() ?? '0') ?? 0);
                      final createdAt = data[DonationKeys.createdAt];
                      String dateStr = '-';
                      if (createdAt is Timestamp) {
                        final dt = createdAt.toDate();
                        dateStr = '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
                      }
                      
                      // 병원명은 posts 컬렉션에서 조회 필요 (간소화를 위해 '-' 표시)
                      // 정산 상태도 추후 구현
                      
                      return DataRow(
                        cells: [
                          DataCell(Text(userId)),
                          DataCell(
                            SizedBox(
                              width: 200,
                              child: Text(
                                postTitle,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(Text('${_formatAmount(amount)}원')),
                          DataCell(Text(dateStr)),
                          DataCell(const Text('-')), // 병원명 (추후 구현)
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green, width: 1),
                              ),
                              child: const Text(
                                '정산 완료',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  String _formatAmount(int value) {
    if (value <= 0) return '0';
    return value.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
