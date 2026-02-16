// 목적: Firestore 'posts' 중 status=='approved'만 최신순으로 실시간 스트림, 피드 카드 리스트.
// 흐름: 메인 피드 탭 선택 시 MainContentMobile/Desktop에서 사용. 빈 상태·로딩·에러 처리.
// 캐시: 동시 구독 병목 방지를 위해 승인 피드 스트림은 앱 전역에서 1회만 생성.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/firestore_keys.dart';
import '../../features/post/post_detail_screen.dart';
import 'story_feed_card.dart';

Stream<QuerySnapshot<Map<String, dynamic>>>? _cachedApprovedPostsStream;
bool _approvedPostsStreamLogDone = false;

/// 승인된 피드용 Firestore 스트림 단일 인스턴스 (중복 구독 방지)
Stream<QuerySnapshot<Map<String, dynamic>>> get _approvedPostsStream {
  _cachedApprovedPostsStream ??= FirebaseFirestore.instance
      .collection(FirestoreCollections.posts)
      .where(FirestorePostKeys.status, isEqualTo: FirestorePostKeys.approved)
      .orderBy(FirestorePostKeys.createdAt, descending: true)
      .snapshots();
  if (!_approvedPostsStreamLogDone) {
    _approvedPostsStreamLogDone = true;
    debugPrint('[SYSTEM] : 피드 데이터 로드 중... (캐시 스트림 1회 연결)');
  }
  return _cachedApprovedPostsStream!;
}

/// 승인된 사연만 최신순으로 표시하는 피드. 빈 상태 시 안내 문구, 이미지 로딩 인디케이터 포함.
class ApprovedPostsFeed extends StatelessWidget {
  const ApprovedPostsFeed({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _approvedPostsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('[SYSTEM] : 피드 스트림 에러: ${snapshot.error}');
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                '목록을 불러오는 중 오류가 발생했습니다.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                '현재 지원을 기다리는 사연이 없습니다.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>? ?? {};
            return StoryFeedCard(postId: doc.id, data: data);
          },
        );
      },
    );
  }
}

/// CustomScrollView 내부에서 사용. orderBy(createdAt, descending: true) 적용, SliverList로 빌드해 상위 스크롤과 일체화.
class ApprovedPostsFeedSliver extends StatelessWidget {
  const ApprovedPostsFeedSliver({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _approvedPostsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('[SYSTEM] : 피드 스트림 에러: ${snapshot.error}');
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  '목록을 불러오는 중 오류가 발생했습니다.',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  '현재 지원을 기다리는 사연이 없습니다.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>? ?? {};
                return StoryFeedCard(postId: doc.id, data: data);
              },
              childCount: docs.length,
            ),
          ),
        );
      },
    );
  }
}

/// 완료된 후원(명예의 전당) — status=='completed'만 표시
class CompletedPostsSliver extends StatelessWidget {
  const CompletedPostsSliver({super.key});

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection(FirestoreCollections.posts)
        .where(FirestorePostKeys.status, isEqualTo: FirestorePostKeys.completed)
        .orderBy(FirestorePostKeys.createdAt, descending: true)
        .limit(20)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError || snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

        return SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '완료된 후원',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>? ?? {};
                    final title = data[FirestorePostKeys.title]?.toString() ?? '(제목 없음)';
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PostDetailScreen(postId: doc.id, data: data),
                              ),
                            );
                          },
                          child: Container(
                            width: 160,
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle, size: 24, color: AppColors.coral),
                                const SizedBox(height: 6),
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
