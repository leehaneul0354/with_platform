// 목적: 탐색 탭 — 어드민 게시물 + 일반 게시물 통합 n×3 그리드. 동일 카드 디자인, 어드민은 badgeText로 구분.
// 흐름: posts + admin_posts 스트림 병합 → 3~5개 게시물마다 어드민 1개 삽입. 클릭: post→상세, admin→linkUrl.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/firestore_keys.dart';
import '../../core/services/admin_post_service.dart';
import '../../shared/widgets/brand_placeholder.dart';
import '../../shared/widgets/cached_network_image_gs.dart';
import '../admin/admin_post_detail_screen.dart';
import '../post/post_detail_screen.dart';

/// 탐색 탭 — 통합 그리드 (일반 + 어드민)
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key, this.streamEnabled = false});

  final bool streamEnabled;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  Stream<QuerySnapshot<Map<String, dynamic>>>? _exploreStream;

  @override
  void initState() {
    super.initState();
    _ensureStream();
  }

  @override
  void didUpdateWidget(covariant ExploreScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.streamEnabled && !oldWidget.streamEnabled) {
      _ensureStream();
    }
  }

  void _ensureStream() {
    if (!widget.streamEnabled || _exploreStream != null) return;
    _exploreStream = FirebaseFirestore.instance
        .collection(FirestoreCollections.posts)
        .where(FirestorePostKeys.status, isEqualTo: FirestorePostKeys.approved)
        .orderBy(FirestorePostKeys.createdAt, descending: true)
        .limit(100)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.streamEnabled || _exploreStream == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('탐색', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _exploreStream,
      builder: (context, postsSnapshot) {
        if (postsSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('탐색', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              backgroundColor: Colors.white,
              elevation: 0,
            ),
            body: const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        if (postsSnapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('탐색', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              backgroundColor: Colors.white,
              elevation: 0,
            ),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  '목록을 불러올 수 없습니다.',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
              ),
            ),
          );
        }
        final postDocs = postsSnapshot.data?.docs ?? [];
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: adminPostsStream(),
          builder: (context, adminSnapshot) {
            final adminDocs = adminSnapshot.data?.docs ?? [];
            final merged = _mergeItems(postDocs, adminDocs);

            if (merged.isEmpty) {
              return CustomScrollView(
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    elevation: 0,
                    backgroundColor: Colors.white,
                    title: const Text(
                      '탐색',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    centerTitle: false,
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                      child: Center(
                        child: Text(
                          '아직 등록된 콘텐츠가 없어요',
                          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  elevation: 0,
                  backgroundColor: Colors.white,
                  title: const Text(
                    '탐색',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  centerTitle: false,
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2,
                      childAspectRatio: 1,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = merged[index];
                        return _ExploreGridTile(item: item);
                      },
                      childCount: merged.length,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 3~5개 일반 게시물마다 어드민 1개 삽입하여 뭉침 방지
  List<_GridItem> _mergeItems(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> postDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> adminDocs,
  ) {
    // 1) 일반 게시물 섞기 (매번 랜덤 순서)
    final shuffledPosts = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(postDocs)
      ..shuffle();

    // 2) 3~5개 간격으로 어드민 게시물 끼워넣기 (패턴: 3,4,5 반복)
    final result = <_GridItem>[];
    int adminIndex = 0;
    final intervals = [3, 4, 5];
    int intervalIdx = 0;
    int sinceLastAdmin = 0;

    for (final post in shuffledPosts) {
      result.add(_GridItem.post(post));
      sinceLastAdmin++;

      if (sinceLastAdmin >= intervals[intervalIdx] && adminIndex < adminDocs.length) {
        result.add(_GridItem.admin(adminDocs[adminIndex]));
        adminIndex++;
        sinceLastAdmin = 0;
        intervalIdx = (intervalIdx + 1) % intervals.length;
      }
    }

    // 남은 어드민 게시물은 리스트 끝에 추가 (뭉침 최소화는 위 루프에서 처리)
    while (adminIndex < adminDocs.length) {
      result.add(_GridItem.admin(adminDocs[adminIndex]));
      adminIndex++;
    }

    return result;
  }
}

/// 그리드 아이템 — 일반 게시물 또는 어드민 게시물
class _GridItem {
  _GridItem._post(this._postDoc) : _adminDoc = null;
  _GridItem._admin(this._adminDoc) : _postDoc = null;

  final QueryDocumentSnapshot<Map<String, dynamic>>? _postDoc;
  final QueryDocumentSnapshot<Map<String, dynamic>>? _adminDoc;

  factory _GridItem.post(QueryDocumentSnapshot<Map<String, dynamic>> doc) => _GridItem._post(doc);
  factory _GridItem.admin(QueryDocumentSnapshot<Map<String, dynamic>> doc) => _GridItem._admin(doc);

  bool get isAdminPost => _adminDoc != null;

  String? get _imageUrl {
    if (isAdminPost) {
      return _adminDoc!.data()[AdminPostKeys.imageUrl]?.toString();
    }
    final data = _postDoc!.data();
    final urls = (data[FirestorePostKeys.imageUrls] as List<dynamic>?)
        ?.map((e) => e?.toString())
        .where((e) => e != null && e.isNotEmpty)
        .cast<String>()
        .toList();
    return urls?.isNotEmpty == true ? urls!.first : null;
  }

  String? get badgeText => isAdminPost
      ? (_adminDoc!.data()[AdminPostKeys.badgeText]?.toString())
      : null;

  String? get linkUrl =>
      isAdminPost ? (_adminDoc!.data()[AdminPostKeys.linkUrl]?.toString()) : null;
}

/// 통합 그리드 타일 — 동일 디자인, 어드민은 badgeText 구분
class _ExploreGridTile extends StatelessWidget {
  const _ExploreGridTile({required this.item});

  final _GridItem item;

  void _onTap(BuildContext context) {
    if (item.isAdminPost) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AdminPostDetailScreen(data: item._adminDoc!.data()),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(
          postId: item._postDoc!.id,
          data: item._postDoc!.data(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _onTap(context),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: AppColors.inactiveBackground.withValues(alpha: 0.5),
              child: item._imageUrl != null && item._imageUrl!.isNotEmpty
                  ? CachedNetworkImageGs(
                      imageUrl: item._imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (_, __, ___) => const BrandPlaceholder(emoji: '🖼'),
                    )
                  : const BrandPlaceholder(emoji: '📝'),
            ),
            if (item.badgeText != null && item.badgeText!.isNotEmpty)
              Positioned(
                left: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.badgeText!,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
