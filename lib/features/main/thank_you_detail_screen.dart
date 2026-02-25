// 목적: 투데이 감사 편지 카드 탭 시 상세 내용 표시. 제목·환자명·본문·이미지(또는 플레이스홀더).
// 흐름: TodayThankYouGrid 카드 탭 → 본 화면(풀스크린 또는 모달). 관리자일 경우 하단 삭제 버튼 노출.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/user_model.dart';
import '../../core/constants/admin_account.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/firestore_keys.dart';
import '../../core/services/admin_service.dart' show deleteDocument, deleteThankYouPost, showDeleteConfirmDialog;
import '../../core/services/like_service.dart';
import '../../shared/widgets/brand_placeholder.dart';
import '../../shared/widgets/cached_network_image_gs.dart';
import '../../shared/widgets/login_prompt_dialog.dart';
import '../auth/login_screen.dart';
import '../auth/signup_screen.dart';
import '../../shared/widgets/comment_section.dart';
import '../../shared/widgets/user_profile_avatar.dart';
import '../post/post_detail_screen.dart';

class ThankYouDetailScreen extends StatefulWidget {
  const ThankYouDetailScreen({
    super.key,
    required this.data,
    this.todayDocId, // today_thank_you 컬렉션의 문서 ID (삭제용)
  });

  final Map<String, dynamic> data;
  final String? todayDocId; // today_thank_you 문서 ID (관리자 삭제용)

  @override
  State<ThankYouDetailScreen> createState() => _ThankYouDetailScreenState();
}

class _ThankYouDetailScreenState extends State<ThankYouDetailScreen> {
  bool _isAdmin = false;
  bool _adminChecked = false;
  Future<_ThankYouLikeInfo>? _likeInfoFuture;
  String? _likeTargetPostId;

  String? _computeLikeTargetPostId() {
    final postId = widget.data[ThankYouPostKeys.postId]?.toString();
    final targetPostId = widget.todayDocId ?? postId;
    if (targetPostId == null || targetPostId.isEmpty) return null;
    return targetPostId;
  }

  Future<_ThankYouLikeInfo> _loadLikeInfo(String postId) async {
    try {
      final userId = AuthRepository.instance.currentUser?.id;
      await Future.delayed(const Duration(milliseconds: 100));
      final likesCollection = FirebaseFirestore.instance
          .collection(FirestoreCollections.thankYouPosts)
          .doc(postId)
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
      return _ThankYouLikeInfo(isLiked: isLiked, likeCount: likeCount);
    } catch (e, st) {
      debugPrint('[ThankYouDetail] load like info 실패 — $e');
      debugPrint('[ThankYouDetail] $st');
      rethrow;
    }
  }

  Future<void> _checkAdmin() async {
    if (!mounted) return;
    var user = AuthRepository.instance.currentUser;
    
    // admin ID 기반 즉시 승인
    bool isAdmin = false;
    if (user != null && user.id == AdminAccount.id) {
      isAdmin = true;
    } else if (user != null) {
      isAdmin = user.type == UserType.admin || user.isAdmin;
      if (!isAdmin) {
        await AuthRepository.instance.fetchUserFromFirestore(user.id);
        final current = AuthRepository.instance.currentUser;
        isAdmin = current != null && (current.type == UserType.admin || current.isAdmin);
      }
    }
    
    if (mounted) {
      setState(() {
        _isAdmin = isAdmin;
        _adminChecked = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _likeTargetPostId = _computeLikeTargetPostId();
    if (_likeTargetPostId != null) {
      _likeInfoFuture = _loadLikeInfo(_likeTargetPostId!);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAdmin());
  }

  @override
  void didUpdateWidget(covariant ThankYouDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldPostId = oldWidget.data[ThankYouPostKeys.postId]?.toString();
    final newPostId = widget.data[ThankYouPostKeys.postId]?.toString();
    final oldTarget = oldWidget.todayDocId ?? oldPostId ?? '';
    final newTarget = widget.todayDocId ?? newPostId ?? '';
    if (oldTarget != newTarget) {
      _likeTargetPostId = _computeLikeTargetPostId();
      if (_likeTargetPostId != null) {
        _likeInfoFuture = _loadLikeInfo(_likeTargetPostId!);
      }
    }
  }

  Widget _buildLikeSection(String postIdFallback) {
    final targetPostId = _likeTargetPostId ?? widget.todayDocId ?? postIdFallback;
    if (targetPostId.isEmpty) return const SizedBox.shrink();
    _likeInfoFuture ??= _loadLikeInfo(targetPostId);
    return FutureBuilder<_ThankYouLikeInfo>(
      future: _likeInfoFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Row(
            children: const [
              Icon(Icons.favorite_border, color: AppColors.textSecondary),
              SizedBox(width: 8),
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          );
        }

        if (snapshot.hasError) {
          return Row(
            children: [
              const Icon(Icons.favorite_border, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  if (!mounted) return;
                  setState(() {
                    _likeInfoFuture = _loadLikeInfo(targetPostId);
                  });
                },
                child: const Text('다시 시도'),
              ),
            ],
          );
        }

        final likeInfo = snapshot.data ?? const _ThankYouLikeInfo(isLiked: false, likeCount: 0);
        final isLiked = likeInfo.isLiked;
        final likeCount = likeInfo.likeCount;

        return Row(
          children: [
            IconButton(
              onPressed: () async {
                final user = AuthRepository.instance.currentUser;
                if (user == null) {
                  if (!mounted) return;
                  LoginPromptDialog.showAsBottomSheet(
                    context,
                    title: '로그인이 필요합니다',
                    content: '좋아요를 누르시려면 로그인 또는 회원가입을 해 주세요.',
                    onLoginTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
                    onSignupTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignupScreen())),
                  );
                  return;
                }
                await toggleLike(
                  postId: targetPostId,
                  postType: 'thank_you',
                  userId: user.id,
                );
                if (!mounted) return;
                setState(() {
                  _likeInfoFuture = _loadLikeInfo(targetPostId);
                });
              },
              icon: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                color: isLiked ? AppColors.coral : AppColors.textSecondary,
              ),
            ),
            Text(
              '$likeCount',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthRepository.instance.currentUser;
    final data = widget.data;
    final title = data[ThankYouPostKeys.title]?.toString() ?? '(제목 없음)';
    final content = data[ThankYouPostKeys.content]?.toString() ?? '';
    final patientName = data[ThankYouPostKeys.patientName]?.toString() ?? '-';
    final imageUrls = data[ThankYouPostKeys.imageUrls] is List
        ? (data[ThankYouPostKeys.imageUrls] as List).cast<String>()
        : <String>[];
    final postId = data[ThankYouPostKeys.postId]?.toString(); // thank_you_posts 문서 ID
    final patientId = data[ThankYouPostKeys.patientId]?.toString() ?? '';
    final isOwner = user != null && user.id == patientId;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '감사 편지',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.yellow,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          if (isOwner || _isAdmin)
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showPostMenu(context, postId),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '작성자: $patientName',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (imageUrls.isNotEmpty) ...[
              ...imageUrls.map((url) => Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImageGs(
                        imageUrl: url,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        borderRadius: BorderRadius.circular(12),
                        placeholder: (_, __) => AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Container(
                            color: AppColors.inactiveBackground,
                            child: const Center(
                              child: SizedBox(
                                width: 32,
                                height: 32,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => _warmPlaceholder(),
                      ),
                    ),
                  )),
              const SizedBox(height: 8),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Text(
                content,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                  height: 1.6,
                ),
              ),
            ),
            // 좋아요 버튼 (스트림 1회 생성으로 중복 구독 방지)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildLikeSection(postId ?? ''),
            ),
            const SizedBox(height: 16),
            // 관련 투병기록 섹션
            _buildRelatedPostSection(data),
            const SizedBox(height: 16),
            // 댓글 섹션
            if ((widget.todayDocId ?? postId) != null)
              CommentSection(
                postId: widget.todayDocId ?? (postId ?? ''),
                postType: 'thank_you',
                patientId: data[ThankYouPostKeys.patientId]?.toString() ?? '',
                postOwnerId: patientId,
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      // 관리자 전용 삭제 버튼 (하단 고정)
      bottomNavigationBar: _isAdmin && _adminChecked && (widget.todayDocId != null || postId != null)
          ? Container(
              padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await showDeleteConfirmDialog(
                      context,
                      title: '감사 편지 삭제',
                      content: '관리자 권한으로 이 편지를 삭제하시겠습니까?\n(투데이 노출과 원본 모두 삭제됩니다)',
                    );
                    if (!context.mounted || confirm != true) return;
                    
                    // today_thank_you와 thank_you_posts 양쪽 삭제
                    bool success = true;
                    if (widget.todayDocId != null) {
                      final ok = await deleteDocument(FirestoreCollections.todayThankYou, widget.todayDocId!);
                      if (!ok) success = false;
                    }
                    if (postId != null) {
                      final ok = await deleteThankYouPost(postId);
                      if (!ok) success = false;
                    }
                    
                    if (!context.mounted) return;
                    Navigator.of(context).pop(); // 화면 닫기
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? '감사 편지가 삭제되었습니다.'
                              : '삭제 처리 중 일부 오류가 발생했습니다.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.delete_outline, size: 20),
                  label: const Text('이 감사 편지 삭제'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade300, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  static Widget _warmPlaceholder() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 200,
        width: double.infinity,
        child: BrandPlaceholder.forThankYou(
          height: 200,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showPostMenu(BuildContext context, String? postId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('게시물 삭제'),
              onTap: () {
                Navigator.of(ctx).pop();
                _confirmDeletePost(context, postId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('수정하기'),
              onTap: () {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('수정 기능은 준비 중입니다.')),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeletePost(BuildContext context, String? postId) async {
    final confirm = await showDeleteConfirmDialog(
      context,
      title: '감사 편지 삭제',
      content: '이 감사 편지를 삭제하시겠습니까?',
    );
    if (confirm != true || !context.mounted) return;
    
    if (postId != null) {
      final ok = await deleteThankYouPost(postId);
      if (!mounted) return;
      if (ok) {
        // today_thank_you도 함께 삭제 시도
        if (widget.todayDocId != null) {
          await deleteDocument(FirestoreCollections.todayThankYou, widget.todayDocId!);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('감사 편지가 삭제되었습니다.')),
        );
        if (!mounted) return;
        Navigator.of(context).pop();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제에 실패했습니다. 다시 시도해 주세요.')),
        );
      }
    }
  }

  /// 관련 투병기록 섹션 빌드
  Widget _buildRelatedPostSection(Map<String, dynamic> data) {
    // relatedPostId 또는 postId 필드 확인 (호환성)
    final relatedPostId = data[ThankYouPostKeys.relatedPostId]?.toString() ??
        data[ThankYouPostKeys.postId]?.toString();
    
    if (relatedPostId == null || relatedPostId.isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<DocumentSnapshot>(
      future: () async {
        await Future.delayed(const Duration(milliseconds: 100));
        return FirebaseFirestore.instance
            .collection(FirestoreCollections.posts)
            .doc(relatedPostId)
            .get();
      }(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink(); // 로딩 중에는 표시하지 않음
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink(); // 데이터가 없으면 표시하지 않음
        }

        final postData = snapshot.data!.data() as Map<String, dynamic>?;
        if (postData == null) {
          return const SizedBox.shrink();
        }

        final postTitle = postData[FirestorePostKeys.title]?.toString() ?? '(제목 없음)';
        final postContent = postData[FirestorePostKeys.content]?.toString() ?? '';
        final createdAt = postData[FirestorePostKeys.createdAt];
        String dateStr = '';
        if (createdAt != null) {
          if (createdAt is Timestamp) {
            final date = createdAt.toDate();
            dateStr = '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
          }
        }
        final shortContent = postContent.length > 80 
            ? '${postContent.substring(0, 80)}...' 
            : postContent;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '후원님의 따뜻한 마음이 이 기록을 만들었습니다',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PostDetailScreen(
                        postId: relatedPostId,
                        data: postData,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 작성자 프로필 아바타
                      UserProfileAvatar(
                        userId: postData[FirestorePostKeys.patientId]?.toString() ?? '',
                        radius: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.article_outlined,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '투병기록',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                                if (dateStr.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    dateStr,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              postTitle,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (shortContent.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                shortContent,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ThankYouLikeInfo {
  final bool isLiked;
  final int likeCount;

  const _ThankYouLikeInfo({
    required this.isLiked,
    required this.likeCount,
  });
}
