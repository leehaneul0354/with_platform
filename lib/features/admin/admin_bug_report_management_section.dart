// 목적: 관리자용 버그 제보 관리 — bug_reports Firestore 스트림 리스트, 상태 업데이트.
// 흐름: AdminMainScreen '버그 제보 관리' 선택 → StreamBuilder로 실시간 목록 → [해결 완료] 클릭 시 status=resolved.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/firestore_keys.dart';
import '../../core/services/bug_report_service.dart';

/// 버그 제보 관리 콘텐츠 — Firestore bug_reports 스트림, 카드 리스트, 해결 완료 버튼
class AdminBugReportManagementSection extends StatelessWidget {
  const AdminBugReportManagementSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.bug_report_outlined, size: 28, color: AppColors.coral),
              const SizedBox(width: 12),
              const Text(
                '버그 제보 관리',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '사용자 제보를 확인하고 해결 상태를 업데이트할 수 있습니다.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection(FirestoreCollections.bugReports)
                .orderBy(BugReportKeys.createdAt, descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '제보 목록을 불러오지 못했습니다: ${snapshot.error}',
                    style: TextStyle(color: Colors.red, fontSize: 14),
                  ),
                );
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(48),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 64,
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '아직 제보된 버그가 없습니다.',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data();
                  return _BugReportCard(
                    docId: doc.id,
                    userId: data[BugReportKeys.userId]?.toString() ?? '-',
                    content: data[BugReportKeys.content]?.toString() ?? '',
                    imageUrl: data[BugReportKeys.imageUrl]?.toString(),
                    status: data[BugReportKeys.status]?.toString() ?? BugReportKeys.statusPending,
                    deviceInfo: data[BugReportKeys.deviceInfo]?.toString() ?? '-',
                    createdAt: data[BugReportKeys.createdAt] is Timestamp
                        ? (data[BugReportKeys.createdAt] as Timestamp).toDate()
                        : null,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 개별 버그 제보 카드 — 상태 배지, 내용, 이미지 썸네일, 기기 정보, 해결 완료 버튼
class _BugReportCard extends StatelessWidget {
  const _BugReportCard({
    required this.docId,
    required this.userId,
    required this.content,
    this.imageUrl,
    required this.status,
    required this.deviceInfo,
    this.createdAt,
  });

  final String docId;
  final String userId;
  final String content;
  final String? imageUrl;
  final String status;
  final String deviceInfo;
  final DateTime? createdAt;

  String get _formattedDate {
    if (createdAt == null) return '-';
    return '${createdAt!.year}.${createdAt!.month.toString().padLeft(2, '0')}.${createdAt!.day.toString().padLeft(2, '0')} '
        '${createdAt!.hour.toString().padLeft(2, '0')}:${createdAt!.minute.toString().padLeft(2, '0')}';
  }

  bool get _isResolved => status == BugReportKeys.statusResolved;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isResolved
              ? const Color(0xFF4CAF50).withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.3),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _StatusBadge(status: status),
                        const SizedBox(width: 8),
                        Text(
                          '유저: $userId',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.devices, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          deviceInfo,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formattedDate,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      content,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (imageUrl != null && imageUrl!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () => _showImageFullscreen(context, imageUrl!),
                        borderRadius: BorderRadius.circular(8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            imageUrl!,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 80,
                              height: 80,
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.image_not_supported, color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '이미지 클릭 시 확대',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!_isResolved)
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: FilledButton.icon(
                    onPressed: () => _markResolved(context),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('해결 완료'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _markResolved(BuildContext context) async {
    try {
      await updateBugReportStatus(docId, BugReportKeys.statusResolved);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('해결 완료로 상태가 변경되었습니다.'),
            backgroundColor: Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('상태 업데이트 실패: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showImageFullscreen(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                },
                errorBuilder: (_, __, ___) => const Icon(Icons.error_outline, color: Colors.white, size: 48),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  bool get _isResolved => status == BugReportKeys.statusResolved;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _isResolved
            ? const Color(0xFF4CAF50).withValues(alpha: 0.15)
            : Colors.orange.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isResolved ? const Color(0xFF4CAF50) : Colors.orange,
          width: 1,
        ),
      ),
      child: Text(
        _isResolved ? '해결됨 (resolved)' : '대기 중 (pending)',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _isResolved ? const Color(0xFF4CAF50) : Colors.orange.shade800,
        ),
      ),
    );
  }
}
