// 목적: 승인된 사연 피드 카드. 환자명·지원 필요 배지, 16:9 이미지, 제목·요약, 진행바 뼈대.
// 흐름: ApprovedPostsFeed에서 사용, 탭 시 PostDetailScreen 이동.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/firestore_keys.dart';
import '../../core/services/comment_service.dart';
import '../../core/services/like_service.dart';
import '../../core/services/admin_service.dart' show showDeletePostConfirmDialog, deletePost;
import '../../features/post/post_detail_screen.dart';
import 'brand_placeholder.dart';
import 'shimmer_image.dart';
import 'user_profile_avatar.dart';

class StoryFeedCard extends StatelessWidget {
  const StoryFeedCard({
    super.key,
    required this.postId,
    required this.data,
  });

  final String postId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final user = AuthRepository.instance.currentUser;
    final patientId = data[FirestorePostKeys.patientId]?.toString() ?? '';
    final isOwner = user != null && user.id == patientId;
    final patientName = data[FirestorePostKeys.patientName]?.toString() ?? '-';
    final title = data[FirestorePostKeys.title]?.toString() ?? '(제목 없음)';
    final content = data[FirestorePostKeys.content]?.toString() ?? '';
    final imageUrls = data[FirestorePostKeys.imageUrls];
    final firstImageUrl = imageUrls is List && (imageUrls as List).isNotEmpty
        ? (imageUrls as List).first.toString()
        : null;
    final isDonationRequest = data[FirestorePostKeys.isDonationRequest] == true ||
        (data[FirestorePostKeys.goalAmount] != null && (data[FirestorePostKeys.goalAmount] as num) > 0) ||
        ((data[FirestorePostKeys.neededItems]?.toString() ?? '').trim().isNotEmpty);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isDonationRequest
            ? BorderSide(color: AppColors.coral.withValues(alpha: 0.4), width: 1.5)
            : BorderSide.none,
      ),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PostDetailScreen(postId: postId, data: data),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Row(
                children: [
                  // 작성자 프로필 아바타
                  UserProfileAvatar(
                    userId: patientId,
                    radius: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      patientName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isDonationRequest)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.coral.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.coral, width: 1),
                      ),
                      child: const Text(
                        '후원하기',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.coral,
                        ),
                      ),
                    ),
                  if (isOwner) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _showPostMenu(context, postId, data),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.more_vert,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: firstImageUrl != null && firstImageUrl.isNotEmpty
                  ? ShimmerImage(
                      imageUrl: firstImageUrl,
                      fit: BoxFit.cover,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                      errorPlaceholderEmoji: isDonationRequest ? '🤝' : '📄',
                    )
                  : _placeholderImage(isDonationRequest),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    content.trim().isEmpty ? '(내용 없음)' : content,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isDonationRequest && (data[FirestorePostKeys.usagePurpose]?.toString() ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Chip(
                          label: Text(
                            data[FirestorePostKeys.usagePurpose].toString().trim(),
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor: AppColors.coral.withValues(alpha: 0.15),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ],
                  if (isDonationRequest) ...[
                    const SizedBox(height: 12),
                    _buildProgressOrGoods(data),
                    const SizedBox(height: 12),
                  ],
                  // 좋아요/댓글 개수 — isLiked 기준 빈하트/채운하트, 브랜드 컬러
                  Row(
                    children: [
                      StreamBuilder<bool>(
                        stream: isLikedStream(
                          postId: postId,
                          postType: 'post',
                          userId: AuthRepository.instance.currentUser?.id ?? '',
                        ),
                        builder: (context, likedSnapshot) {
                          final isLiked = likedSnapshot.data ?? false;
                          return StreamBuilder<int>(
                            stream: likeCountStream(
                              postId: postId,
                              postType: 'post',
                            ),
                            builder: (context, countSnapshot) {
                              final likeCount = countSnapshot.data ?? 0;
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: () async {
                                      final uid = AuthRepository.instance.currentUser?.id;
                                      if (uid == null) return;
                                      await toggleLike(
                                        postId: postId,
                                        postType: 'post',
                                        userId: uid,
                                      );
                                    },
                                    behavior: HitTestBehavior.opaque,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                      child: Icon(
                                        isLiked ? Icons.favorite : Icons.favorite_border,
                                        size: 16,
                                        color: isLiked ? AppColors.coral : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$likeCount',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(width: 16),
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: commentsStream(
                          postId: postId,
                          postType: 'post',
                        ),
                        builder: (context, snapshot) {
                          final commentCount = snapshot.data?.docs.length ?? 0;
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$commentCount',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressOrGoods(Map<String, dynamic> data) {
    final fundingType = data[FirestorePostKeys.fundingType]?.toString() ?? FirestorePostKeys.fundingTypeMoney;
    final usagePurpose = (data[FirestorePostKeys.usagePurpose]?.toString() ?? '').trim();
    if (fundingType == FirestorePostKeys.fundingTypeGoods) {
      final needed = data[FirestorePostKeys.neededItems]?.toString() ?? '';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (usagePurpose.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '사용 목적: $usagePurpose',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Text(
            '후원물품',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          if (needed.isNotEmpty)
            Text(
              needed,
              style: const TextStyle(fontSize: 12, color: AppColors.coral, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      );
    }
    final current = _toInt(data[FirestorePostKeys.currentAmount]);
    final goal = _toInt(data[FirestorePostKeys.goalAmount]);
    final progress = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    final percent = goal > 0 ? ((current / goal) * 100).round() : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '후원 진행',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            Text(
              '$percent%',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.coral),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: AppColors.inactiveBackground,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.coral),
          ),
        ),
      ],
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v != null) return int.tryParse(v.toString()) ?? 0;
    return 0;
  }

  Widget _placeholderImage(bool isDonationRequest) {
    return BrandPlaceholder(
      fit: BoxFit.cover,
      emoji: isDonationRequest ? '🤝' : '📄',
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
    );
  }

  void _showPostMenu(BuildContext context, String postId, Map<String, dynamic> data) {
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

  Future<void> _confirmDeletePost(BuildContext context, String postId) async {
    final confirm = await showDeletePostConfirmDialog(context);
    if (confirm != true || !context.mounted) return;
    final ok = await deletePost(postId);
    if (!context.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('게시물이 삭제되었습니다.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('삭제에 실패했습니다. 다시 시도해 주세요.')),
      );
    }
  }
}

