// 목적: 투데이 탭 '환자들의 감사편지' — today_thank_you 실시간 스트림, 2열 그리드, 카드 탭 시 상세 화면.
// 흐름: initState에서 스트림을 변수에 캐시 (중복 구독 방지).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/auth/auth_repository.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import 'login_prompt_dialog.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/firestore_keys.dart';
import '../../core/services/comment_service.dart';
import '../../core/services/like_service.dart';
import '../../features/main/thank_you_detail_screen.dart';
import 'brand_placeholder.dart';
import 'cached_network_image_gs.dart';

class TodayThankYouGrid extends StatefulWidget {
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
  State<TodayThankYouGrid> createState() => _TodayThankYouGridState();
}

class _TodayThankYouGridState extends State<TodayThankYouGrid> {
  Stream<QuerySnapshot<Map<String, dynamic>>>? _cachedStream;

  @override
  void initState() {
    super.initState();
    _cachedStream = FirebaseFirestore.instance
        .collection(FirestoreCollections.todayThankYou)
        .orderBy(ThankYouPostKeys.createdAt, descending: true)
        .limit(20)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _cachedStream,
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
          padding: widget.padding,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: widget.crossAxisCount,
              childAspectRatio: widget.childAspectRatio,
              crossAxisSpacing: widget.spacing,
              mainAxisSpacing: widget.spacing,
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
                      ? CachedNetworkImageGs(
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
                    // 좋아요/댓글 개수 — isLiked 기준 빈하트/채운하트, 브랜드 컬러
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        StreamBuilder<bool>(
                          stream: isLikedStream(
                            postId: postId,
                            postType: 'thank_you',
                            userId: AuthRepository.instance.currentUser?.id ?? '',
                          ),
                          builder: (context, likedSnapshot) {
                            final isLiked = likedSnapshot.data ?? false;
                            return StreamBuilder<int>(
                              stream: likeCountStream(
                                postId: postId,
                                postType: 'thank_you',
                              ),
                              builder: (context, countSnapshot) {
                                final likeCount = countSnapshot.data ?? 0;
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GestureDetector(
                                      onTap: () async {
                                        final uid = AuthRepository.instance.currentUser?.id;
                                        if (uid == null) {
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
                                          postId: postId,
                                          postType: 'thank_you',
                                          userId: uid,
                                        );
                                      },
                                      behavior: HitTestBehavior.opaque,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                                        child: Icon(
                                          isLiked ? Icons.favorite : Icons.favorite_border,
                                          size: 12,
                                          color: isLiked ? AppColors.coral : AppColors.textSecondary,
                                        ),
                                      ),
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
    return const SizedBox.expand(
      child: BrandPlaceholder(
        fit: BoxFit.cover,
        variant: PlaceholderVariant.thankYou,
      ),
    );
  }
}
