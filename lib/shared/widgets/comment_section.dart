// 목적: 댓글 리스트 및 입력창 위젯. 후원자 뱃지 표시 및 실시간 업데이트.
// 흐름: 댓글 스트림 구독 → 리스트 표시 → 입력창에서 작성 → 후원자 판별 → 저장.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/firestore_keys.dart';
import '../../core/services/comment_service.dart';
import 'user_profile_avatar.dart';

class CommentSection extends StatefulWidget {
  const CommentSection({
    super.key,
    required this.postId,
    required this.postType,
    required this.patientId,
    this.postOwnerId, // 게시물 작성자 ID (댓글 삭제 권한용)
  });

  final String postId;
  final String postType; // 'post' 또는 'thank_you'
  final String patientId; // 게시물 작성자(수혜자) ID
  final String? postOwnerId; // 게시물 작성자 ID (댓글 삭제 권한용)

  @override
  State<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final user = AuthRepository.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 후 댓글을 작성할 수 있습니다.')),
      );
      return;
    }

    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSubmitting = true);

    final success = await addComment(
      postId: widget.postId,
      postType: widget.postType,
      userId: user.id,
      userName: user.nickname,
      content: content,
      patientId: widget.patientId,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      _commentController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('댓글이 작성되었습니다.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('댓글 작성에 실패했습니다. 다시 시도해 주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 댓글 입력창
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: AppColors.inactiveBackground, width: 1),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: '댓글을 입력하세요...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: AppColors.inactiveBackground),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: AppColors.inactiveBackground),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: AppColors.yellow, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submitComment(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _isSubmitting ? null : _submitComment,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.send, color: AppColors.yellow),
              ),
            ],
          ),
        ),
        // 댓글 리스트
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: commentsStream(
            postId: widget.postId,
            postType: widget.postType,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '댓글을 불러오는 중 오류가 발생했습니다.',
                  style: TextStyle(color: Colors.red.shade700),
                ),
              );
            }

            final comments = snapshot.data?.docs ?? [];
            if (comments.isEmpty) {
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.favorite_outline,
                      size: 48,
                      color: AppColors.textSecondary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '첫 번째 응원의 주인공이 되어주세요! 🕊️',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: comments.length,
              separatorBuilder: (_, __) => Divider(
                height: 20,
                thickness: 0.5,
                color: AppColors.inactiveBackground.withValues(alpha: 0.5),
              ),
              itemBuilder: (context, index) {
                final doc = comments[index];
                final data = doc.data();
                final content = data[CommentKeys.content]?.toString() ?? '';
                final userName = data[CommentKeys.userName]?.toString() ?? '익명';
                final userId = data[CommentKeys.userId]?.toString() ?? '';
                final isSponsor = data[CommentKeys.isSponsor] == true;
                final timestamp = data[CommentKeys.timestamp] as Timestamp?;

                return _CommentItem(
                  commentId: doc.id,
                  content: content,
                  userName: userName,
                  userId: userId,
                  isSponsor: isSponsor,
                  timestamp: timestamp,
                  postId: widget.postId,
                  postType: widget.postType,
                  postOwnerId: widget.postOwnerId,
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _CommentItem extends StatelessWidget {
  const _CommentItem({
    required this.commentId,
    required this.content,
    required this.userName,
    required this.userId,
    required this.isSponsor,
    required this.timestamp,
    required this.postId,
    required this.postType,
    this.postOwnerId,
  });

  final String commentId;
  final String content;
  final String userName;
  final String userId;
  final bool isSponsor;
  final Timestamp? timestamp;
  final String postId;
  final String postType;
  final String? postOwnerId; // 게시물 작성자 ID

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '';
    final date = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthRepository.instance.currentUser;
    // 댓글 작성자 본인 또는 관리자 또는 게시물 작성자 본인일 경우 삭제 가능
    final canDelete = user != null && (
      user.id == userId || 
      user.isAdmin || 
      (postOwnerId != null && user.id == postOwnerId)
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: isSponsor
            ? const Color(0xFFF0F9FF) // 연한 푸른빛 배경
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 댓글 작성자 프로필 아바타
              UserProfileAvatar(
                userId: userId,
                radius: 16,
              ),
              const SizedBox(width: 10),
              Text(
                userName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (isSponsor) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.yellow,
                        AppColors.yellow.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.yellow.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('✨', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        'WITH Angel',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              if (timestamp != null)
                Text(
                  _formatTimestamp(timestamp),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                  ),
                ),
              if (canDelete) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('댓글 삭제'),
                        content: const Text('이 댓글을 삭제하시겠습니까?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('취소'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('삭제'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && context.mounted) {
                      await deleteComment(
                        postId: postId,
                        postType: postType,
                        commentId: commentId,
                        userId: user!.id,
                        isAdmin: user.isAdmin,
                      );
                    }
                  },
                  child: Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: Colors.red.shade400,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
