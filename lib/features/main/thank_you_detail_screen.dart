// 목적: 투데이 감사 편지 카드 탭 시 상세 내용 표시. 제목·환자명·본문·이미지(또는 플레이스홀더).
// 흐름: TodayThankYouGrid 카드 탭 → 본 화면(풀스크린 또는 모달). 관리자일 경우 하단 삭제 버튼 노출.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/user_model.dart';
import '../../core/constants/admin_account.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/firestore_keys.dart';
import '../../core/services/admin_service.dart' show deleteDocument, deleteThankYouPost, showDeleteConfirmDialog;
import '../../core/services/like_service.dart';
import '../../shared/widgets/comment_section.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAdmin());
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final title = data[ThankYouPostKeys.title]?.toString() ?? '(제목 없음)';
    final content = data[ThankYouPostKeys.content]?.toString() ?? '';
    final patientName = data[ThankYouPostKeys.patientName]?.toString() ?? '-';
    final imageUrls = data[ThankYouPostKeys.imageUrls] is List
        ? (data[ThankYouPostKeys.imageUrls] as List).cast<String>()
        : <String>[];
    final postId = data[ThankYouPostKeys.postId]?.toString(); // thank_you_posts 문서 ID

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
                      child: CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.contain,
                        width: double.infinity,
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
            // 좋아요 버튼
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: StreamBuilder<bool>(
                stream: isLikedStream(
                  postId: widget.todayDocId ?? postId ?? '',
                  postType: 'thank_you',
                  userId: AuthRepository.instance.currentUser?.id ?? '',
                ),
                builder: (context, likedSnapshot) {
                  final isLiked = likedSnapshot.data ?? false;
                  return StreamBuilder<int>(
                    stream: likeCountStream(
                      postId: widget.todayDocId ?? postId ?? '',
                      postType: 'thank_you',
                    ),
                    builder: (context, countSnapshot) {
                      final likeCount = countSnapshot.data ?? 0;
                      return Row(
                        children: [
                          IconButton(
                            onPressed: () async {
                              final user = AuthRepository.instance.currentUser;
                              if (user == null) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('로그인 후 좋아요를 누를 수 있습니다.')),
                                );
                                return;
                              }
                              final targetPostId = widget.todayDocId ?? postId ?? '';
                              if (targetPostId.isEmpty) return;
                              await toggleLike(
                                postId: targetPostId,
                                postType: 'thank_you',
                                userId: user.id,
                              );
                            },
                            icon: Icon(
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              color: isLiked ? Colors.red : AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '$likeCount',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            // 댓글 섹션
            if ((widget.todayDocId ?? postId) != null)
              CommentSection(
                postId: widget.todayDocId ?? postId!,
                postType: 'thank_you',
                patientId: data[ThankYouPostKeys.patientId]?.toString() ?? '',
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      // 관리자 전용 삭제 버튼 (하단 고정)
      bottomNavigationBar: _isAdmin && _adminChecked && (widget.todayDocId != null || postId != null)
          ? Container(
              color: Colors.white,
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
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.coral.withValues(alpha: 0.2),
            AppColors.yellow.withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(Icons.mail_outline, size: 48, color: AppColors.textSecondary),
      ),
    );
  }
}
