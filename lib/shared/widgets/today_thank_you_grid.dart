// 목적: 투데이 탭 '환자들의 감사편지' — today_thank_you 실시간 스트림, 2열 그리드, 카드 탭 시 상세 화면.
// 흐름: 메인 스크롤/데스크톱에서 사용. 이미지 없으면 따뜻한 플레이스홀더, 카드 간격 8, BorderRadius 12.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/firestore_keys.dart';
import '../../core/services/comment_service.dart';
import '../../core/services/like_service.dart';
import '../../features/main/thank_you_detail_screen.dart';

class TodayThankYouGrid extends StatelessWidget {
  const TodayThankYouGrid({
    super.key,
    this.crossAxisCount = 2,
    this.childAspectRatio = 0.75,
    this.spacing = 8,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final int crossAxisCount;
  final double childAspectRatio;
  final double spacing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(FirestoreCollections.todayThankYou)
          .orderBy(ThankYouPostKeys.createdAt, descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '감사 편지를 불러올 수 없습니다.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Center(
              child: Text(
                '아직 감사 편지가 없어요',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
            ),
          );
        }
        return Padding(
          padding: padding,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: childAspectRatio,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>? ?? {};
              return _ThankYouGridCard(
                data: data,
                postId: doc.id, // today_thank_you 문서 ID (댓글/좋아요용)
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ThankYouDetailScreen(
                        data: data,
                        todayDocId: doc.id, // today_thank_you 문서 ID 전달 (관리자 삭제용)
                      ),
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

class _ThankYouGridCard extends StatelessWidget {
  const _ThankYouGridCard({
    required this.data,
    required this.postId,
    required this.onTap,
  });

  final Map<String, dynamic> data;
  final String postId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = data[ThankYouPostKeys.title]?.toString() ?? '(제목 없음)';
    final patientName = data[ThankYouPostKeys.patientName]?.toString() ?? '-';
    final imageUrls = data[ThankYouPostKeys.imageUrls];
    final urls = imageUrls is List && (imageUrls as List).isNotEmpty
        ? (imageUrls as List).cast<String>()
        : <String>[];
    final firstUrl = urls.isNotEmpty ? urls.first : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: firstUrl != null && firstUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: firstUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _warmPlaceholder(),
                          errorWidget: (_, __, ___) => _warmPlaceholder(),
                        )
                      : _warmPlaceholder(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      patientName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // 좋아요/댓글 개수
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        StreamBuilder<int>(
                          stream: likeCountStream(
                            postId: postId,
                            postType: 'thank_you',
                          ),
                          builder: (context, snapshot) {
                            final likeCount = snapshot.data ?? 0;
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.favorite,
                                  size: 12,
                                  color: Colors.red.shade400,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$likeCount',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: commentsStream(
                            postId: postId,
                            postType: 'thank_you',
                          ),
                          builder: (context, snapshot) {
                            final commentCount = snapshot.data?.docs.length ?? 0;
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 12,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$commentCount',
                                  style: TextStyle(
                                    fontSize: 11,
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
      ),
    );
  }

  static Widget _warmPlaceholder() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.coral.withValues(alpha: 0.15),
            AppColors.yellow.withValues(alpha: 0.25),
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.mail_outline, size: 40, color: AppColors.textSecondary),
      ),
    );
  }
}
