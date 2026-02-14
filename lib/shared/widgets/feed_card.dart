// 목적: 피드 한 건 표시 (프로필, 이미지, 좋아요/댓글 수).
// 흐름: 메인 피드 리스트에서 반복 렌더링.

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// 피드 한 건 카드 (이미지 URL은 추후 연동)
class FeedCard extends StatelessWidget {
  const FeedCard({
    super.key,
    required this.authorName,
    this.likeCount = 0,
    this.commentCount = 0,
    this.bodyText = '',
    this.imageUrl,
  });

  final String authorName;
  final int likeCount;
  final int commentCount;
  final String bodyText;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.inactiveBackground,
                  child: Text(
                    authorName.isNotEmpty ? authorName[0] : '?',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    authorName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Icon(Icons.star_outline, color: AppColors.yellow, size: 22),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Container(
              width: double.infinity,
              color: AppColors.inactiveBackground,
              child: imageUrl != null && imageUrl!.isNotEmpty
                  ? Image.network(imageUrl!, fit: BoxFit.cover)
                  : const Center(
                      child: Icon(Icons.image_outlined, size: 48, color: AppColors.textSecondary),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Icon(Icons.favorite_border, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text('$likeCount', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(width: 16),
                Icon(Icons.chat_bubble_outline, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text('$commentCount', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          if (bodyText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                bodyText,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}
