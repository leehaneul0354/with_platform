// 목적: 관리자 전용 대시보드. 다크 네이비 테마, 통계·승인 대기 사연 카드·풀시트 상세.
// 흐름: 권한 검사(Firestore type=='admin' 또는 로컬 isAdmin) → 통계·pending 실시간 스트림 → 탭 시 풀시트 상세·승인/반려.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/user_model.dart';
import '../../core/constants/firestore_keys.dart';
import '../main/main_screen.dart';

/// 관리자 전용 컬러 — 다크 네이비 테마
class _AdminTheme {
  _AdminTheme._();
  static const Color darkNavy = Color(0xFF0D1B2A);
  static const Color navy = Color(0xFF1B263B);
  static const Color slate = Color(0xFF415A77);
  static const Color light = Color(0xFFE0E1DD);
  static const Color accent = Color(0xFF4CAF50); // 연두/그린 액센트
  static const Color danger = Color(0xFFE53935);
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _accessChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async => await _checkAccess());
  }

  Future<void> _checkAccess() async {
    if (!mounted) return;
    final user = AuthRepository.instance.currentUser;
    bool isAdmin = user != null && (user.type == UserType.admin || user.isAdmin);
    if (!isAdmin && user != null) {
      final _ = await AuthRepository.instance.fetchUserFromFirestore(user.id);
      final current = AuthRepository.instance.currentUser;
      isAdmin = current != null && (current.type == UserType.admin || current.isAdmin);
    }
    if (!mounted) return;
    if (!isAdmin) {
      final u = AuthRepository.instance.currentUser;
      debugPrint('[ADMIN PAGE] 권한 실패 — 현재 유저 type=${u?.type?.name ?? "null"}, isAdmin=${u?.isAdmin}, id=${u?.id}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('권한이 없습니다')),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
      return;
    }
    _accessChecked = true;
    debugPrint('[ADMIN PAGE] 권한 확인 완료 — 관리자 모드 (type=${user?.type?.name})');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_accessChecked) {
      final user = AuthRepository.instance.currentUser;
      final allowed = user != null && (user.type == UserType.admin || user.isAdmin);
      if (!allowed) {
        return const Scaffold(
          backgroundColor: _AdminTheme.darkNavy,
          body: Center(child: CircularProgressIndicator(color: _AdminTheme.light)),
        );
      }
      _accessChecked = true;
    }

    return Scaffold(
      backgroundColor: _AdminTheme.darkNavy,
      appBar: AppBar(
        title: const Text(
          'WITH 관리자 컨트롤 타워',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _AdminTheme.light,
          ),
        ),
        backgroundColor: _AdminTheme.navy,
        foregroundColor: _AdminTheme.light,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const MainScreen()),
              );
            },
            child: const Text('메인으로', style: TextStyle(color: _AdminTheme.light)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            _StatsSection(),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '승인 대기 중인 사연',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _AdminTheme.light,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _PendingPostsList(onTapPost: _openDetailSheet),
          ],
        ),
      ),
    );
  }

  void _openDetailSheet(String docId, Map<String, dynamic> data) {
    debugPrint('[SYSTEM] : 관리자 사연 상세 열림 docId=$docId');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _AdminTheme.navy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _PostDetailSheet(
        docId: docId,
        data: data,
        onClose: () => Navigator.of(ctx).pop(),
        onApproved: () async {
          Navigator.of(ctx).pop();
          await _updateStatus(docId, FirestorePostKeys.approved);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('승인되었습니다.')));
        },
        onRejected: () async {
          Navigator.of(ctx).pop();
          await _updateStatus(docId, FirestorePostKeys.rejected);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('반려되었습니다.')));
        },
      ),
    );
  }

  Future<void> _updateStatus(String docId, String status) async {
    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.posts)
          .doc(docId)
          .update({FirestorePostKeys.status: status});
      debugPrint('[SYSTEM] : 게시물 상태 업데이트 완료 docId=$docId status=$status');
    } catch (e) {
      debugPrint('[SYSTEM] : 게시물 상태 업데이트 실패 $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('처리 실패: $e')));
      }
    }
  }
}

/// 상단 통계 카드: 총 사연 수, 승인 대기 수
class _StatsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(FirestoreCollections.posts)
                  .snapshots(),
              builder: (context, snap) {
                final total = snap.data?.docs.length ?? 0;
                return _StatCard(
                  label: '총 사연 수',
                  value: '$total',
                  icon: Icons.article_outlined,
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(FirestoreCollections.posts)
                  .where(FirestorePostKeys.status, isEqualTo: FirestorePostKeys.pending)
                  .snapshots(),
              builder: (context, snap) {
                final pending = snap.data?.docs.length ?? 0;
                return _StatCard(
                  label: '승인 대기',
                  value: '$pending',
                  icon: Icons.pending_actions,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: _AdminTheme.navy,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _AdminTheme.slate, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28, color: _AdminTheme.accent),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: _AdminTheme.slate,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _AdminTheme.light,
            ),
          ),
        ],
      ),
    );
  }
}

/// 승인 대기 리스트 — 카드(썸네일/제목/작성자/신청일)
class _PendingPostsList extends StatelessWidget {
  const _PendingPostsList({required this.onTapPost});

  final void Function(String docId, Map<String, dynamic> data) onTapPost;

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection(FirestoreCollections.posts)
        .where(FirestorePostKeys.status, isEqualTo: FirestorePostKeys.pending)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('[ADMIN PAGE] 게시물 스트림 에러: ${snapshot.error}');
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              '목록을 불러오는 중 오류가 발생했습니다.',
              style: TextStyle(fontSize: 14, color: _AdminTheme.slate),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator(color: _AdminTheme.light)),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              '승인 대기 중인 사연이 없습니다.',
              style: TextStyle(fontSize: 14, color: _AdminTheme.slate),
            ),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>? ?? {};
            return _PostCard(
              docId: doc.id,
              data: data,
              onTap: () => onTapPost(doc.id, data),
            );
          },
        );
      },
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
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
    final imageUrls = data[FirestorePostKeys.imageUrls];
    final urls = imageUrls is List ? (imageUrls as List).cast<String>() : <String>[];
    final firstUrl = urls.isNotEmpty ? urls.first : null;
    final createdAt = data[FirestorePostKeys.createdAt];
    String dateStr = '-';
    if (createdAt is Timestamp) {
      final dt = createdAt.toDate();
      dateStr = '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
    }

    return Material(
      color: _AdminTheme.navy,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: firstUrl != null
                      ? Image.network(
                          firstUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: _AdminTheme.slate,
                            child: const Icon(Icons.image_not_supported, color: _AdminTheme.light),
                          ),
                        )
                      : Container(
                          color: _AdminTheme.slate,
                          child: const Icon(Icons.image, color: _AdminTheme.light),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _AdminTheme.light,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      patientName,
                      style: const TextStyle(fontSize: 13, color: _AdminTheme.slate),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '신청일 $dateStr',
                      style: const TextStyle(fontSize: 12, color: _AdminTheme.slate),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: _AdminTheme.slate, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// 풀시트 상세: 사진 크게, 최종 승인 / 반려
class _PostDetailSheet extends StatelessWidget {
  const _PostDetailSheet({
    required this.docId,
    required this.data,
    required this.onClose,
    required this.onApproved,
    required this.onRejected,
  });

  final String docId;
  final Map<String, dynamic> data;
  final VoidCallback onClose;
  final VoidCallback onApproved;
  final VoidCallback onRejected;

  @override
  Widget build(BuildContext context) {
    final title = data[FirestorePostKeys.title]?.toString() ?? '(제목 없음)';
    final content = data[FirestorePostKeys.content]?.toString() ?? '';
    final patientName = data[FirestorePostKeys.patientName]?.toString() ?? '-';
    final imageUrls = data[FirestorePostKeys.imageUrls] is List
        ? (data[FirestorePostKeys.imageUrls] as List).cast<String>()
        : <String>[];

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 1,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _AdminTheme.slate,
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
                        color: _AdminTheme.light,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close, color: _AdminTheme.light),
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
                      style: const TextStyle(fontSize: 14, color: _AdminTheme.slate),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '내용',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _AdminTheme.light,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      content,
                      style: const TextStyle(fontSize: 14, color: _AdminTheme.light, height: 1.5),
                    ),
                    if (imageUrls.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text(
                        '첨부 사진',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _AdminTheme.light,
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
                                  color: _AdminTheme.slate,
                                  child: const Center(child: Icon(Icons.broken_image, color: _AdminTheme.light)),
                                ),
                              ),
                            ),
                          )),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              onRejected();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _AdminTheme.danger,
                              side: const BorderSide(color: _AdminTheme.danger),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('반려'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              onApproved();
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: _AdminTheme.accent,
                              foregroundColor: _AdminTheme.darkNavy,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('최종 승인'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
