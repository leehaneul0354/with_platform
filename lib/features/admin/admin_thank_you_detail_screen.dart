// 목적: 관리자 전용 감사 편지 상세 화면. 진입 시 admin 권한 재확인, 하단 [삭제]/[승인] 고정.
// 흐름: AdminDashboard 감사 편지 리스트 탭 → 본 화면 → 권한 없으면 즉시 퇴장 → 이미지/환자명/내용/사용목적 표시 → 삭제 또는 승인.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/user_model.dart';
import '../../core/constants/admin_account.dart';
import '../../core/constants/firestore_keys.dart';
import '../../core/services/admin_service.dart';
import '../../core/services/like_service.dart';
import '../../shared/widgets/brand_placeholder.dart';
import '../../shared/widgets/cached_network_image_gs.dart';
import '../../shared/widgets/comment_section.dart';

/// 관리자 전용 컬러 (AdminDashboard와 동일)
class _AdminTheme {
  _AdminTheme._();
  static const Color darkNavy = Color(0xFF0D1B2A);
  static const Color navy = Color(0xFF1B263B);
  static const Color slate = Color(0xFF415A77);
  static const Color light = Color(0xFFE0E1DD);
  static const Color accent = Color(0xFF4CAF50);
  static const Color danger = Color(0xFFE53935);
}

class AdminThankYouDetailScreen extends StatefulWidget {
  const AdminThankYouDetailScreen({
    super.key,
    required this.docId,
    required this.data,
  });

  final String docId;
  final Map<String, dynamic> data;

  @override
  State<AdminThankYouDetailScreen> createState() => _AdminThankYouDetailScreenState();
}

class _AdminThankYouDetailScreenState extends State<AdminThankYouDetailScreen> {
  bool _accessChecked = false;
  bool _isAdmin = false;
  Future<_AdminThankYouLikeInfo>? _likeInfoFuture;

  Future<_AdminThankYouLikeInfo> _loadLikeInfo() async {
    try {
      final userId = AuthRepository.instance.currentUser?.id;
      await Future.delayed(const Duration(milliseconds: 100));
      final likesCollection = FirebaseFirestore.instance
          .collection(FirestoreCollections.thankYouPosts)
          .doc(widget.docId)
          .collection(FirestoreCollections.likes);
      final snapshot = await likesCollection.get();
      final docs = snapshot.docs;
      final likeCount = docs.length;
      final isLiked = userId != null &&
          userId.isNotEmpty &&
          docs.any((doc) {
            final data = doc.data();
            return data[LikeKeys.userId]?.toString() == userId;
          });
      return _AdminThankYouLikeInfo(isLiked: isLiked, likeCount: likeCount);
    } catch (e, st) {
      debugPrint('[AdminThankYouDetail] load like info 실패 — $e');
      debugPrint('[AdminThankYouDetail] $st');
      rethrow;
    }
  }

  Future<void> _checkAdmin() async {
    if (!mounted) return;
    var user = AuthRepository.instance.currentUser;
    
    // admin ID 기반 즉시 승인 (Firestore 조회 전)
    bool isAdmin = false;
    if (user != null && user.id == AdminAccount.id) {
      isAdmin = true;
    } else if (user != null) {
      // 일반 권한 체크
      isAdmin = user.type == UserType.admin || user.isAdmin;
      if (!isAdmin) {
        // Firestore 재조회
        await AuthRepository.instance.fetchUserFromFirestore(user.id);
        final current = AuthRepository.instance.currentUser;
        isAdmin = current != null && (current.type == UserType.admin || current.isAdmin);
      }
    }
    
    if (!mounted) return;
    if (!isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('권한이 없습니다')),
      );
      Navigator.of(context).pop();
      return;
    }
    _isAdmin = true;
    _accessChecked = true;
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _likeInfoFuture = _loadLikeInfo();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAdmin());
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final title = data[ThankYouPostKeys.title]?.toString() ?? '(제목 없음)';
    final content = data[ThankYouPostKeys.content]?.toString() ?? '';
    final patientName = data[ThankYouPostKeys.patientName]?.toString() ?? '-';
    final postTitle = data[ThankYouPostKeys.postTitle]?.toString();
    final usagePurpose = (data[ThankYouPostKeys.usagePurpose]?.toString() ?? '').trim();
    final imageUrls = data[ThankYouPostKeys.imageUrls] is List
        ? (data[ThankYouPostKeys.imageUrls] as List).cast<String>()
        : <String>[];

    return Scaffold(
      backgroundColor: _AdminTheme.darkNavy,
      appBar: AppBar(
        title: const Text(
          '감사 편지 상세 (관리자)',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _AdminTheme.light),
        ),
        backgroundColor: _AdminTheme.navy,
        foregroundColor: _AdminTheme.light,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 제목
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _AdminTheme.light,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            // 환자 이름 · 연결 게시물 · 사용 목적 (한눈에)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _AdminTheme.navy,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _AdminTheme.slate, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 18, color: _AdminTheme.accent),
                      const SizedBox(width: 6),
                      Text(
                        '환자 이름',
                        style: const TextStyle(fontSize: 12, color: _AdminTheme.slate),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          patientName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _AdminTheme.light,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (postTitle != null && postTitle.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.article_outlined, size: 18, color: _AdminTheme.slate),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '연결 게시물: $postTitle',
                            style: const TextStyle(fontSize: 13, color: _AdminTheme.slate),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (usagePurpose.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.savings_outlined, size: 18, color: _AdminTheme.accent),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '사용 목적: $usagePurpose',
                            style: const TextStyle(fontSize: 13, color: _AdminTheme.accent),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            // 편지 내용
            const Text(
              '편지 내용',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _AdminTheme.slate,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _AdminTheme.navy,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _AdminTheme.slate, width: 1),
              ),
              child: Text(
                content,
                style: const TextStyle(fontSize: 15, color: _AdminTheme.light, height: 1.6),
              ),
            ),
            // 이미지
            if (imageUrls.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                '첨부 이미지',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _AdminTheme.slate,
                ),
              ),
              const SizedBox(height: 8),
              ...imageUrls.map((url) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImageGs(
                        imageUrl: url,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        borderRadius: BorderRadius.circular(12),
                        placeholder: (_, __) => Container(
                          height: 120,
                          color: _AdminTheme.slate,
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: _AdminTheme.light),
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            height: 120,
                            width: double.infinity,
                            child: BrandPlaceholder.forThankYou(
                              height: 120,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )),
            ],
            const SizedBox(height: 24),
            // 좋아요 버튼 (FutureBuilder + get() 단발 조회)
            FutureBuilder<_AdminThankYouLikeInfo>(
              future: _likeInfoFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Row(
                    children: const [
                      Icon(Icons.favorite_border, color: _AdminTheme.light),
                      SizedBox(width: 8),
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(_AdminTheme.light),
                        ),
                      ),
                    ],
                  );
                }

                if (snapshot.hasError) {
                  return Row(
                    children: [
                      const Icon(Icons.favorite_border, color: _AdminTheme.light),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          if (!mounted) return;
                          setState(() {
                            _likeInfoFuture = _loadLikeInfo();
                          });
                        },
                        child: const Text('다시 시도'),
                      ),
                    ],
                  );
                }

                final likeInfo = snapshot.data ?? const _AdminThankYouLikeInfo(isLiked: false, likeCount: 0);
                final isLiked = likeInfo.isLiked;
                final likeCount = likeInfo.likeCount;

                return Row(
                  children: [
                    IconButton(
                      onPressed: () async {
                        final user = AuthRepository.instance.currentUser;
                        if (user == null) return;
                        await toggleLike(
                          postId: widget.docId,
                          postType: 'thank_you',
                          userId: user.id,
                        );
                        if (!mounted) return;
                        setState(() {
                          _likeInfoFuture = _loadLikeInfo();
                        });
                      },
                      icon: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? Colors.red : _AdminTheme.light,
                      ),
                    ),
                    Text(
                      '$likeCount',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _AdminTheme.light,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            // 댓글 섹션
            CommentSection(
              postId: widget.docId,
              postType: 'thank_you',
              patientId: widget.data[ThankYouPostKeys.patientId]?.toString() ?? '',
              postOwnerId: widget.data[ThankYouPostKeys.patientId]?.toString(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      // 하단 고정 버튼 영역
      bottomNavigationBar: Container(
        color: _AdminTheme.navy,
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isAdmin
                      ? () async {
                          final confirm = await showDeleteConfirmDialog(
                            context,
                            title: '감사 편지 삭제',
                            content: '정말 이 감사 편지를 삭제하시겠습니까?',
                          );
                          if (!context.mounted || confirm != true) return;
                          final ok = await deleteThankYouPost(widget.docId);
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok ? '감사 편지가 삭제되었습니다.' : '삭제 실패. 권한을 확인해 주세요.',
                              ),
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.delete_outline, size: 20),
                  label: const Text('삭제'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _AdminTheme.danger,
                    side: BorderSide(color: _AdminTheme.danger.withOpacity(0.7), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    disabledForegroundColor: _AdminTheme.slate,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isAdmin
                      ? () async {
                          final ok = await approveThankYouPost(widget.docId, widget.data);
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok
                                    ? '승인되었습니다. 투데이에 노출됩니다.'
                                    : '승인 처리에 실패했습니다.',
                              ),
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: const Text('승인'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _AdminTheme.accent,
                    foregroundColor: _AdminTheme.darkNavy,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    disabledBackgroundColor: _AdminTheme.slate,
                    disabledForegroundColor: _AdminTheme.light.withOpacity(0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminThankYouLikeInfo {
  final bool isLiked;
  final int likeCount;

  const _AdminThankYouLikeInfo({
    required this.isLiked,
    required this.likeCount,
  });
}
