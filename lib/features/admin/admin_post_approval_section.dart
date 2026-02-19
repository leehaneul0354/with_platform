// 목적: 게시글 승인 섹션 - 투병 기록 및 감사 편지 승인 관리
// 흐름: AdminMainScreen의 '게시글 승인' 카테고리 선택 시 표시

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/firestore_keys.dart';
import '../../core/services/admin_service.dart';
import 'admin_thank_you_detail_screen.dart';

class AdminPostApprovalSection extends StatefulWidget {
  const AdminPostApprovalSection({super.key});

  @override
  State<AdminPostApprovalSection> createState() => _AdminPostApprovalSectionState();
}

class _AdminPostApprovalSectionState extends State<AdminPostApprovalSection> {
  int _selectedTab = 0; // 0: 투병 기록, 1: 감사 편지
  bool _streamReady = false; // 스트림 준비 완료 플래그

  @override
  void initState() {
    super.initState();
    // 탭 전환 시에도 순차 로딩 적용
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        setState(() {
          _streamReady = true;
        });
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '게시글 승인',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              // 탭 전환
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    _buildTabButton('투병 기록', 0),
                    _buildTabButton('감사 편지', 1),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 콘텐츠 (순차 로딩)
        Expanded(
          child: !_streamReady
              ? const Center(child: CircularProgressIndicator())
              : (_selectedTab == 0 ? _StrugglePostsList() : _ThankYouPostsList()),
        ),
      ],
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () {
        // 탭 전환 시 스트림 재초기화 (순차 로딩)
        setState(() {
          _selectedTab = index;
          _streamReady = false;
        });
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _streamReady = true;
            });
          }
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.yellow : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// 투병 기록 승인 리스트
class _StrugglePostsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(FirestoreCollections.posts)
          .where(FirestorePostKeys.status, isEqualTo: FirestorePostKeys.pending)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('에러: ${snapshot.error}'),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.article_outlined, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                Text(
                  '승인 대기 중인 게시글이 없습니다.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.all(24),
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
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              return _PostListTile(
                docId: doc.id,
                data: data,
                onTap: () => _showPostDetail(context, doc.id, data),
              );
            },
          ),
        );
      },
    );
  }

  void _showPostDetail(BuildContext context, String docId, Map<String, dynamic> data) {
    // AdminDashboardScreen의 상세 시트 로직 재사용
    // 다크 테마 대신 밝은 테마로 표시
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _PostDetailSheetLight(
        docId: docId,
        data: data,
        onClose: () => Navigator.of(ctx).pop(),
        onApproved: (int? goalAmount, String? neededItems, String? usagePurpose) async {
          Navigator.of(ctx).pop();
          await _approvePost(docId, goalAmount, neededItems, usagePurpose);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('승인되었습니다.')),
            );
          }
        },
        onRejected: () async {
          Navigator.of(ctx).pop();
          await _rejectPost(docId);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('반려되었습니다.')),
            );
          }
        },
      ),
    );
  }

  Future<void> _approvePost(String docId, int? goalAmount, String? neededItems, String? usagePurpose) async {
    try {
      final updates = <String, dynamic>{FirestorePostKeys.status: FirestorePostKeys.approved};
      if (goalAmount != null) updates[FirestorePostKeys.goalAmount] = goalAmount;
      if (neededItems != null) updates[FirestorePostKeys.neededItems] = neededItems;
      if (usagePurpose != null) updates[FirestorePostKeys.usagePurpose] = usagePurpose;
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.posts)
          .doc(docId)
          .update(updates);
    } catch (e) {
      debugPrint('승인 실패: $e');
    }
  }

  Future<void> _rejectPost(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.posts)
          .doc(docId)
          .update({FirestorePostKeys.status: FirestorePostKeys.rejected});
    } catch (e) {
      debugPrint('반려 실패: $e');
    }
  }
}

/// 감사 편지 승인 리스트
class _ThankYouPostsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(FirestoreCollections.thankYouPosts)
          .where(ThankYouPostKeys.status, isEqualTo: ThankYouPostKeys.pending)
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
                Icon(Icons.mail_outline, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                Text(
                  '승인 대기 중인 감사 편지가 없습니다.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.all(24),
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
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              return _ThankYouListTile(
                docId: doc.id,
                data: data,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AdminThankYouDetailScreen(docId: doc.id, data: data),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

/// 게시글 리스트 타일
class _PostListTile extends StatelessWidget {
  const _PostListTile({
    required this.docId,
    required this.data,
    required this.onTap,
  });

  final String docId;
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = data[FirestorePostKeys.title]?.toString() ?? '(제목 없음)';
    final patientName = data[FirestorePostKeys.patientName]?.toString() ?? '-';
    final createdAt = data[FirestorePostKeys.createdAt];
    String dateStr = '-';
    if (createdAt is Timestamp) {
      final dt = createdAt.toDate();
      dateStr = '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text('작성자: $patientName | 신청일: $dateStr'),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// 감사 편지 리스트 타일
class _ThankYouListTile extends StatelessWidget {
  const _ThankYouListTile({
    required this.docId,
    required this.data,
    required this.onTap,
  });

  final String docId;
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = data[ThankYouPostKeys.title]?.toString() ?? '(제목 없음)';
    final patientName = data[ThankYouPostKeys.patientName]?.toString() ?? '-';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text('작성자: $patientName'),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// 게시글 상세 시트 (밝은 테마 버전)
class _PostDetailSheetLight extends StatefulWidget {
  const _PostDetailSheetLight({
    required this.docId,
    required this.data,
    required this.onClose,
    required this.onApproved,
    required this.onRejected,
  });

  final String docId;
  final Map<String, dynamic> data;
  final VoidCallback onClose;
  final void Function(int? goalAmount, String? neededItems, String? usagePurpose) onApproved;
  final VoidCallback onRejected;

  @override
  State<_PostDetailSheetLight> createState() => _PostDetailSheetLightState();
}

class _PostDetailSheetLightState extends State<_PostDetailSheetLight> {
  late final TextEditingController _goalController;
  late final TextEditingController _neededController;
  late final TextEditingController _usagePurposeController;

  @override
  void initState() {
    super.initState();
    final goal = widget.data[FirestorePostKeys.goalAmount];
    _goalController = TextEditingController(
      text: goal is int ? goal.toString() : goal is num ? goal.toInt().toString() : '',
    );
    _neededController = TextEditingController(
      text: widget.data[FirestorePostKeys.neededItems]?.toString() ?? '',
    );
    _usagePurposeController = TextEditingController(
      text: widget.data[FirestorePostKeys.usagePurpose]?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _goalController.dispose();
    _neededController.dispose();
    _usagePurposeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.data[FirestorePostKeys.title]?.toString() ?? '(제목 없음)';
    final content = widget.data[FirestorePostKeys.content]?.toString() ?? '';
    final patientName = widget.data[FirestorePostKeys.patientName]?.toString() ?? '-';
    final imageUrls = widget.data[FirestorePostKeys.imageUrls] is List
        ? (widget.data[FirestorePostKeys.imageUrls] as List).cast<String>()
        : <String>[];

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 1,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.inactiveBackground,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '작성자: $patientName',
                      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '내용',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      content,
                      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '관리자 조정 (승인 시 반영)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _goalController,
                      decoration: const InputDecoration(
                        labelText: '목표 금액 (원)',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _neededController,
                      decoration: const InputDecoration(
                        labelText: '필요 물품 리스트',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _usagePurposeController,
                      decoration: const InputDecoration(
                        labelText: '사용 목적',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    if (imageUrls.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text(
                        '첨부 사진',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...imageUrls.map((url) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                url,
                                fit: BoxFit.contain,
                                width: double.infinity,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 120,
                                  color: AppColors.inactiveBackground,
                                  child: const Center(child: Icon(Icons.broken_image)),
                                ),
                              ),
                            ),
                          )),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onRejected,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('반려'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        final goalStr = _goalController.text.trim();
                        final neededStr = _neededController.text.trim();
                        final usageStr = _usagePurposeController.text.trim();
                        final goal = goalStr.isEmpty ? null : int.tryParse(goalStr);
                        widget.onApproved(goal, neededStr.isEmpty ? null : neededStr, usageStr.isEmpty ? null : usageStr);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.yellow,
                        foregroundColor: AppColors.textPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('최종 승인'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
