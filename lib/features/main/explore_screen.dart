// 목적: 탐색 탭 — 인스타그램 탐색창 스타일 n×3 그리드 레이아웃.
// 흐름: 워터폴 로딩 — streamEnabled 시에만 스트림 구독. 스트림은 initState에서 변수에 할당 (중복 빌드 방지).

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/firestore_keys.dart';
import '../../shared/widgets/brand_placeholder.dart';
import '../post/post_detail_screen.dart';

/// 탐색 탭 — 이미지 중심 n×3 그리드 (인스타그램 스타일)
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
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
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
        if (snapshot.hasError) {
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
        final docs = snapshot.data?.docs ?? [];
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
            if (docs.isEmpty)
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
              )
            else
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
                      final doc = docs[index];
                      final data = doc.data();
                      final imageUrls = (data?[FirestorePostKeys.imageUrls] as List<dynamic>?)
                          ?.map((e) => e?.toString())
                          .where((e) => e != null && e.isNotEmpty)
                          .cast<String>()
                          .toList() ?? [];
                      final firstImage = imageUrls.isNotEmpty ? imageUrls.first! : null;
                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PostDetailScreen(postId: doc.id, data: data),
                            ),
                          );
                        },
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            color: AppColors.inactiveBackground.withValues(alpha: 0.5),
                            child: firstImage != null
                                ? CachedNetworkImage(
                                    imageUrl: firstImage,
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
                        ),
                      );
                    },
                    childCount: docs.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
