// 목적: 관리자 전용 대시보드. 다크 네이비 테마, 통계·승인 대기 사연 카드·풀시트 상세.
// 흐름: 권한 검사(Firestore type=='admin' 또는 로컬 isAdmin) → 통계·pending 실시간 스트림 → 탭 시 풀시트 상세·승인/반려.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/user_model.dart';
import '../../core/constants/firestore_keys.dart';
import '../../core/services/admin_service.dart';
import 'admin_thank_you_detail_screen.dart';
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
  static const Color coral = Color(0xFFFF7F7F); // 후원 요청 배지
  static const Color generalBadge = Color(0xFF5C6BC0); // 일반 기록 배지 (푸른계열)
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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
          bottom: TabBar(
            indicatorColor: _AdminTheme.accent,
            labelColor: _AdminTheme.light,
            unselectedLabelColor: _AdminTheme.slate,
            tabs: const [
              Tab(text: '투병 기록 승인'),
              Tab(text: '감사 편지 승인'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('메인으로', style: TextStyle(color: _AdminTheme.light)),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _StruggleTab(
              onTapPost: _openDetailSheet,
              onDeletePost: _confirmAndDeletePost,
            ),
            _ThankYouTab(
              onApprove: _approveThankYou,
              onDelete: _deleteThankYou,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveThankYou(String docId, Map<String, dynamic> data) async {
    final ok = await approveThankYouPost(docId, data);
    if (mounted) {
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('감사 편지가 승인되어 투데이에 노출됩니다.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('승인 처리에 실패했습니다.')));
      }
    }
  }

  /// 감사 편지 삭제: 피드 삭제와 동일 플로우 — 공통 확인 다이얼로그 → Firestore 삭제 → 스낵바.
  Future<void> _deleteThankYou(String docId) async {
    final confirm = await showDeleteConfirmDialog(
      context,
      title: '감사 편지 삭제',
      content: '정말 이 감사 편지를 삭제하시겠습니까?',
    );
    if (confirm != true) return;
    final ok = await deleteThankYouPost(docId);
    if (mounted) {
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('감사 편지가 삭제되었습니다.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('삭제 실패. 권한을 확인해 주세요.')));
      }
    }
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
        isAdmin: true,
        onClose: () => Navigator.of(ctx).pop(),
        onApproved: (int? goalAmount, String? neededItems, String? usagePurpose) async {
          Navigator.of(ctx).pop();
          await _approvePostWithAdjustments(docId, goalAmount: goalAmount, neededItems: neededItems, usagePurpose: usagePurpose);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('승인되었습니다.')));
        },
        onRejected: () async {
          Navigator.of(ctx).pop();
          await _updateStatus(docId, FirestorePostKeys.rejected);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('반려되었습니다.')));
        },
        onDelete: () async {
          final navigator = Navigator.of(ctx);
          final confirm = await showDeletePostConfirmDialog(ctx) ?? false;
          if (!confirm) return;
          debugPrint('[SYSTEM] : [ADMIN] 대시보드 상세 시트에서 게시물 삭제 시도 - ID: $docId');
          navigator.pop();
          final ok = await deletePost(docId);
          if (mounted) {
            if (ok) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('게시물이 삭제되었습니다')));
            } else {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('삭제 실패. 권한을 확인해 주세요.')));
            }
          }
        },
      ),
    );
  }

  Future<void> _confirmAndDeletePost(String docId) async {
    debugPrint('[SYSTEM] : [ADMIN] 리스트에서 게시물 삭제 요청 - ID: $docId');
    final confirm = await showDeletePostConfirmDialog(context) ?? false;
    if (!confirm) return;
    final ok = await deletePost(docId);
    if (mounted) {
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('게시물이 삭제되었습니다')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('삭제 실패. 권한을 확인해 주세요.')));
      }
    }
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

  /// 승인 시 목표 금액·필요 물품·사용 목적 조정값 반영
  Future<void> _approvePostWithAdjustments(String docId, {int? goalAmount, String? neededItems, String? usagePurpose}) async {
    try {
      final updates = <String, dynamic>{FirestorePostKeys.status: FirestorePostKeys.approved};
      if (goalAmount != null) updates[FirestorePostKeys.goalAmount] = goalAmount;
      if (neededItems != null) updates[FirestorePostKeys.neededItems] = neededItems;
      if (usagePurpose != null) updates[FirestorePostKeys.usagePurpose] = usagePurpose;
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.posts)
          .doc(docId)
          .update(updates);
      debugPrint('[SYSTEM] : 게시물 승인·조정 완료 docId=$docId');
    } catch (e) {
      debugPrint('[SYSTEM] : 승인·조정 실패 $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('처리 실패: $e')));
      }
    }
  }
}

/// 탭 1: 투병 기록 승인 — 통계 + 필터(전체/일반/후원) + 승인 대기 리스트(삭제 버튼 상시)
/// 탭 전환 시 스트림이 꼬이지 않도록 KeepAlive로 유지
class _StruggleTab extends StatefulWidget {
  const _StruggleTab({
    required this.onTapPost,
    required this.onDeletePost,
  });

  final void Function(String docId, Map<String, dynamic> data) onTapPost;
  final Future<void> Function(String docId) onDeletePost;

  @override
  State<_StruggleTab> createState() => _StruggleTabState();
}

class _StruggleTabState extends State<_StruggleTab> with AutomaticKeepAliveClientMixin {
  /// '전체' | '일반' | '후원'
  String _filter = '전체';

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          _StatsSection(),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              '승인 대기 중인 사연',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _AdminTheme.light,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  label: const Text('전체'),
                  selected: _filter == '전체',
                  onSelected: (_) => setState(() => _filter = '전체'),
                  selectedColor: _AdminTheme.accent.withValues(alpha: 0.4),
                  labelStyle: TextStyle(
                    color: _filter == '전체' ? _AdminTheme.light : _AdminTheme.slate,
                    fontWeight: _filter == '전체' ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                ChoiceChip(
                  label: const Text('일반 기록'),
                  selected: _filter == '일반',
                  onSelected: (_) => setState(() => _filter = '일반'),
                  selectedColor: _AdminTheme.generalBadge.withValues(alpha: 0.4),
                  labelStyle: TextStyle(
                    color: _filter == '일반' ? _AdminTheme.light : _AdminTheme.slate,
                    fontWeight: _filter == '일반' ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                ChoiceChip(
                  label: const Text('후원 요청'),
                  selected: _filter == '후원',
                  onSelected: (_) => setState(() => _filter = '후원'),
                  selectedColor: _AdminTheme.coral.withValues(alpha: 0.4),
                  labelStyle: TextStyle(
                    color: _filter == '후원' ? _AdminTheme.light : _AdminTheme.slate,
                    fontWeight: _filter == '후원' ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _PendingPostsList(
            onTapPost: widget.onTapPost,
            onDeletePost: widget.onDeletePost,
            isAdmin: true,
            filter: _filter,
          ),
        ],
      ),
    );
  }
}

/// 탭 2: 감사 편지 승인 — 대기 중인 감사 편지 리스트, 승인 시 today_thank_you로 이동, 삭제 시 확인 다이얼로그
/// Stream을 탭 내부에서 독립 관리, 인덱스 에러 시 orderBy 없이 폴백하여 리스트가 안 뜨는 현상 방지
class _ThankYouTab extends StatefulWidget {
  const _ThankYouTab({
    required this.onApprove,
    required this.onDelete,
  });

  final void Function(String docId, Map<String, dynamic> data) onApprove;
  final Future<void> Function(String docId) onDelete;

  @override
  State<_ThankYouTab> createState() => _ThankYouTabState();
}

class _ThankYouTabState extends State<_ThankYouTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  /// orderBy(createdAt) 사용 시 복합 인덱스 필요. 에러 시 false로 바꿔 orderBy 없이 조회
  bool _useOrderBy = true;

  Stream<QuerySnapshot<Map<String, dynamic>>> _buildStream() {
    final base = FirebaseFirestore.instance
        .collection(FirestoreCollections.thankYouPosts)
        .where(ThankYouPostKeys.status, isEqualTo: ThankYouPostKeys.pending);
    if (_useOrderBy) {
      return base.orderBy(ThankYouPostKeys.createdAt, descending: true).snapshots();
    }
    return base.snapshots();
  }

  void _onStreamError(Object error, StackTrace? stackTrace) {
    final msg = error.toString();
    debugPrint('[ADMIN] 감사 편지 쿼리 오류: $msg');
    if (stackTrace != null) debugPrint('[ADMIN] $stackTrace');
    // Firebase 인덱스 생성 링크 추출 (예: "You can create it here: https://...")
    final uriMatch = RegExp(r'https://[^\s\)\]\"]+').firstMatch(msg);
    if (uriMatch != null) {
      debugPrint('[ADMIN] Firebase 복합 인덱스 생성 링크: ${uriMatch.group(0)}');
    }
    // setState는 빌드 중에 호출되면 안 되므로, 프레임 끝난 뒤 실행
    if (_useOrderBy && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _useOrderBy = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<QuerySnapshot>(
      stream: _buildStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          _onStreamError(snapshot.error!, snapshot.stackTrace);
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _useOrderBy
                      ? '목록을 불러오는 중 오류가 발생했습니다. 정렬 없이 다시 불러옵니다.'
                      : '목록을 불러오는 중 오류가 발생했습니다.',
                  style: TextStyle(fontSize: 14, color: _AdminTheme.slate),
                  textAlign: TextAlign.center,
                ),
                if (!_useOrderBy)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: CircularProgressIndicator(color: _AdminTheme.light),
                  ),
              ],
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _AdminTheme.light));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              '승인 대기 중인 감사 편지가 없습니다.',
              style: TextStyle(fontSize: 14, color: _AdminTheme.slate),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>? ?? {};
            final letterTitle = data[ThankYouPostKeys.title]?.toString() ?? '(제목 없음)';
            final patientName = data[ThankYouPostKeys.patientName]?.toString() ?? '-';
            final postTitle = data[ThankYouPostKeys.postTitle]?.toString();
            final usagePurpose = (data[ThankYouPostKeys.usagePurpose]?.toString() ?? '').trim();
            final imageUrls = data[ThankYouPostKeys.imageUrls];
            final urls = imageUrls is List ? (imageUrls as List).cast<String>() : <String>[];
            final firstUrl = urls.isNotEmpty ? urls.first : null;
            
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AdminThankYouDetailScreen(
                      docId: doc.id,
                      data: data,
                    ),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: _AdminTheme.navy,
                  borderRadius: BorderRadius.circular(12),
                ),
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
                            ? CachedNetworkImage(
                                imageUrl: firstUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  color: _AdminTheme.slate,
                                  child: const Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: _AdminTheme.light),
                                    ),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  color: _AdminTheme.slate,
                                  child: const Icon(Icons.image_not_supported, color: _AdminTheme.light),
                                ),
                              )
                            : Container(
                                color: _AdminTheme.slate,
                                child: const Icon(Icons.mail_outline, color: _AdminTheme.light),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            patientName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _AdminTheme.accent,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (postTitle != null && postTitle.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              '게시물: $postTitle',
                              style: const TextStyle(fontSize: 12, color: _AdminTheme.slate),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            letterTitle,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _AdminTheme.light,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (usagePurpose.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              '사용 목적: $usagePurpose',
                              style: const TextStyle(fontSize: 12, color: _AdminTheme.slate),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    // 우측 액션: 상세 보기 + 삭제 (IconButton은 GestureDetector의 onTap과 충돌 방지)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => AdminThankYouDetailScreen(
                                  docId: doc.id,
                                  data: data,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: const Icon(Icons.chevron_right, color: _AdminTheme.slate, size: 24),
                          ),
                        ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => widget.onDelete(doc.id),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: const Icon(Icons.delete_outline, color: _AdminTheme.danger, size: 22),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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

/// 승인 대기 리스트 — 필터(전체/일반/후원) 적용, 카드(썸네일/제목/배지/작성자/신청일), 관리자일 때 삭제 아이콘
class _PendingPostsList extends StatelessWidget {
  const _PendingPostsList({
    required this.onTapPost,
    this.onDeletePost,
    this.isAdmin = false,
    this.filter = '전체',
  });

  final void Function(String docId, Map<String, dynamic> data) onTapPost;
  final Future<void> Function(String docId)? onDeletePost;
  final bool isAdmin;
  /// '전체' | '일반' | '후원'
  final String filter;

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
        final filtered = docs.where((d) {
          final data = d.data() as Map<String, dynamic>? ?? {};
          final isDonation = _isDonationRequestFromData(data);
          if (filter == '전체') return true;
          if (filter == '일반') return !isDonation;
          return isDonation; // '후원'
        }).toList();
        if (filtered.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              filter == '전체'
                  ? '승인 대기 중인 사연이 없습니다.'
                  : '${filter == '일반' ? '일반 기록' : '후원 요청'}으로 필터된 결과가 없습니다.',
              style: TextStyle(fontSize: 14, color: _AdminTheme.slate),
            ),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = filtered[index];
            final data = doc.data() as Map<String, dynamic>? ?? {};
            return _PostCard(
              docId: doc.id,
              data: data,
              onTap: () => onTapPost(doc.id, data),
              onDelete: isAdmin && onDeletePost != null ? () => onDeletePost!(doc.id) : null,
            );
          },
        );
      },
    );
  }
}

/// data 기준 후원 요청 여부 (기존 문서 호환: goalAmount/neededItems로 판단)
bool _isDonationRequestFromData(Map<String, dynamic> data) {
  if (data[FirestorePostKeys.isDonationRequest] == true) return true;
  final goal = data[FirestorePostKeys.goalAmount];
  if (goal != null && (goal is num) && (goal as num) > 0) return true;
  final needed = (data[FirestorePostKeys.neededItems]?.toString() ?? '').trim();
  return needed.isNotEmpty;
}

Widget _summaryRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: _AdminTheme.slate, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, color: _AdminTheme.light),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.docId,
    required this.data,
    required this.onTap,
    this.onDelete,
  });

  final String docId;
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

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
    final isDonationRequest = _isDonationRequestFromData(data);

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
                            decoration: const BoxDecoration(color: _AdminTheme.slate),
                            child: const Icon(Icons.image_not_supported, color: _AdminTheme.light),
                          ),
                        )
                      : Container(
                          decoration: const BoxDecoration(color: _AdminTheme.slate),
                          child: const Icon(Icons.image, color: _AdminTheme.light),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _AdminTheme.light,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDonationRequest
                                ? _AdminTheme.coral.withValues(alpha: 0.25)
                                : _AdminTheme.generalBadge.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDonationRequest ? _AdminTheme.coral : _AdminTheme.generalBadge,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            isDonationRequest ? '후원 요청' : '일반 기록',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDonationRequest ? _AdminTheme.coral : _AdminTheme.generalBadge,
                            ),
                          ),
                        ),
                      ],
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
              if (onDelete != null)
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, color: _AdminTheme.danger, size: 22),
                  tooltip: '게시물 삭제',
                )
              else
                const Icon(Icons.chevron_right, color: _AdminTheme.slate, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// 풀시트 상세: 사진·내용, 관리자 조정(목표 금액/필요 물품), 최종 승인/반려/삭제
class _PostDetailSheet extends StatefulWidget {
  const _PostDetailSheet({
    required this.docId,
    required this.data,
    required this.isAdmin,
    required this.onClose,
    required this.onApproved,
    required this.onRejected,
    required this.onDelete,
  });

  final String docId;
  final Map<String, dynamic> data;
  final bool isAdmin;
  final VoidCallback onClose;
  final void Function(int? goalAmount, String? neededItems, String? usagePurpose) onApproved;
  final VoidCallback onRejected;
  final VoidCallback onDelete;

  @override
  State<_PostDetailSheet> createState() => _PostDetailSheetState();
}

class _PostDetailSheetState extends State<_PostDetailSheet> {
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
    debugPrint('[ADMIN] : 상세 시트 빌드됨, isAdmin status: ${widget.isAdmin}');
    final title = widget.data[FirestorePostKeys.title]?.toString() ?? '(제목 없음)';
    final content = widget.data[FirestorePostKeys.content]?.toString() ?? '';
    final patientName = widget.data[FirestorePostKeys.patientName]?.toString() ?? '-';
    final fundingType = widget.data[FirestorePostKeys.fundingType]?.toString() ?? FirestorePostKeys.fundingTypeMoney;
    final imageUrls = widget.data[FirestorePostKeys.imageUrls] is List
        ? (widget.data[FirestorePostKeys.imageUrls] as List).cast<String>()
        : <String>[];
    final isDonationRequest = _isDonationRequestFromData(widget.data);
    final goalAmount = widget.data[FirestorePostKeys.goalAmount];
    final neededItems = (widget.data[FirestorePostKeys.neededItems]?.toString() ?? '').trim();
    final usagePurpose = (widget.data[FirestorePostKeys.usagePurpose]?.toString() ?? '').trim();
    final hospitalName = (widget.data[FirestorePostKeys.hospitalName]?.toString() ?? '').trim();
    final deliveryInfo = (widget.data[FirestorePostKeys.deliveryInfo]?.toString() ?? '').trim();
    final goodsQuantity = (widget.data[FirestorePostKeys.goodsQuantity]?.toString() ?? '').trim();

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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDonationRequest
                                ? _AdminTheme.coral.withValues(alpha: 0.25)
                                : _AdminTheme.generalBadge.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDonationRequest ? _AdminTheme.coral : _AdminTheme.generalBadge,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            isDonationRequest ? '후원 요청' : '일반 기록',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDonationRequest ? _AdminTheme.coral : _AdminTheme.generalBadge,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _AdminTheme.light,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onClose,
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
                    if (isDonationRequest && (goalAmount != null || neededItems.isNotEmpty || usagePurpose.isNotEmpty || hospitalName.isNotEmpty || deliveryInfo.isNotEmpty)) ...[
                      const SizedBox(height: 16),
                      const Text(
                        '후원 요청 요약 (검수 참고)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _AdminTheme.accent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _AdminTheme.darkNavy,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _AdminTheme.coral.withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _summaryRow('후원 유형', fundingType == FirestorePostKeys.fundingTypeGoods ? '후원물품' : '후원금'),
                            if (goalAmount != null && (goalAmount is num) && (goalAmount as num) > 0)
                              _summaryRow('목표 금액', '${(goalAmount as num).toStringAsFixed(0)}원'),
                            if (neededItems.isNotEmpty) _summaryRow('필요 물품', neededItems),
                            if (goodsQuantity.isNotEmpty) _summaryRow('수량', goodsQuantity),
                            if (deliveryInfo.isNotEmpty) _summaryRow('배송 정보', deliveryInfo),
                            if (hospitalName.isNotEmpty) _summaryRow('병원명', hospitalName),
                            if (usagePurpose.isNotEmpty) _summaryRow('사용 목적', usagePurpose),
                          ],
                        ),
                      ),
                    ],
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
                    const SizedBox(height: 20),
                    const Text(
                      '관리자 조정 (승인 시 반영)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _AdminTheme.accent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _goalController,
                      decoration: const InputDecoration(
                        labelText: '목표 금액 (원)',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: _AdminTheme.navy,
                      ),
                      style: const TextStyle(color: _AdminTheme.light),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _neededController,
                      decoration: const InputDecoration(
                        labelText: '필요 물품 리스트',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: _AdminTheme.navy,
                      ),
                      style: const TextStyle(color: _AdminTheme.light),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _usagePurposeController,
                      decoration: const InputDecoration(
                        labelText: '사용 목적 (환자 입력값 확인·수정)',
                        hintText: '예: 치료비, 간병비, 긴급 의료비 지원',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: _AdminTheme.navy,
                      ),
                      style: const TextStyle(color: _AdminTheme.light),
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
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: widget.onRejected,
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
                            final goalStr = _goalController.text.trim();
                            final neededStr = _neededController.text.trim();
                            final usageStr = _usagePurposeController.text.trim();
                            final goal = goalStr.isEmpty ? null : int.tryParse(goalStr);
                            widget.onApproved(goal, neededStr.isEmpty ? null : neededStr, usageStr.isEmpty ? null : usageStr);
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
                  if (widget.isAdmin) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: widget.onDelete,
                        icon: const Icon(Icons.delete_outline, size: 20),
                        label: const Text('게시물 삭제'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _AdminTheme.danger,
                          foregroundColor: _AdminTheme.light,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
