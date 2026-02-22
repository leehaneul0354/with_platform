// 목적: Firestore 'posts' 중 status=='approved'만 최신순으로 실시간 스트림, 피드 카드 리스트.
// 흐름: 메인 피드 탭 선택 시 MainContentMobile/Desktop에서 사용. 빈 상태·로딩·에러 처리.
// 캐시: 동시 구독 병목 방지를 위해 승인 피드 스트림은 앱 전역에서 1회만 생성.
// 로딩: 스켈레톤 카드 최소 2개, 3초 타임아웃 시 새로고침 안내.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/firestore_keys.dart';
import '../../features/post/post_detail_screen.dart';
import 'story_feed_card.dart';
import 'shimmer_placeholder.dart';

Stream<QuerySnapshot<Map<String, dynamic>>>? _cachedApprovedPostsStream;
bool _approvedPostsStreamLogDone = false;
bool _approvedPostsStreamInitialized = false;

/// 피드 스트림 초기화 (앱 시작 시 한 번만 호출)
/// 강제 초기화가 필요한 경우 force=true로 호출 가능
void initializeApprovedPostsStream({bool force = false}) {
  if (_approvedPostsStreamInitialized && !force) {
    debugPrint('[SYSTEM] : 피드 스트림 이미 초기화됨 - 중복 초기화 방지');
    return;
  }
  
  // 강제 초기화 시 기존 캐시 클리어
  if (force) {
    _cachedApprovedPostsStream = null;
    _approvedPostsStreamLogDone = false;
    debugPrint('[SYSTEM] : 피드 스트림 강제 초기화 - 기존 캐시 클리어');
  }
  
  _approvedPostsStreamInitialized = true;
  debugPrint('[SYSTEM] : 피드 스트림 초기화 완료 (force: $force)');
}

/// 피드 스트림 캐시 클리어 (로그아웃 시 호출)
void clearApprovedPostsStreamCache() {
  _cachedApprovedPostsStream = null;
  _approvedPostsStreamLogDone = false;
  _approvedPostsStreamInitialized = false;
  debugPrint('[SYSTEM] : 피드 스트림 캐시 완전 삭제됨');
}

/// 승인된 피드용 Firestore 스트림 단일 인스턴스 (중복 구독 방지)
/// 초기화되지 않았을 경우 자동으로 초기화 시도
Stream<QuerySnapshot<Map<String, dynamic>>> get _approvedPostsStream {
  // 초기화되지 않았으면 자동 초기화 시도
  if (!_approvedPostsStreamInitialized) {
    debugPrint('[SYSTEM] : 피드 스트림 미초기화 - 자동 초기화 시도');
    initializeApprovedPostsStream();
  }
  
  // 스트림이 없거나 null이면 새로 생성
  _cachedApprovedPostsStream ??= FirebaseFirestore.instance
      .collection(FirestoreCollections.posts)
      .where(FirestorePostKeys.status, isEqualTo: FirestorePostKeys.approved)
      .orderBy(FirestorePostKeys.createdAt, descending: true)
      .snapshots()
      .handleError((error) {
        debugPrint('[SYSTEM] : 피드 스트림 에러 발생 - $error');
        // 에러 발생 시 스트림을 null로 리셋하여 재시도 가능하게 함
        _cachedApprovedPostsStream = null;
        _approvedPostsStreamLogDone = false;
        // 초기화 플래그는 유지 (재시도 시 다시 초기화 가능하도록)
        return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
      });
  
  if (!_approvedPostsStreamLogDone) {
    _approvedPostsStreamLogDone = true;
    debugPrint('[SYSTEM] : 피드 데이터 로드 중... (캐시 스트림 1회 연결)');
  }
  return _cachedApprovedPostsStream!;
}

/// 승인된 사연만 최신순으로 표시하는 피드. 빈 상태 시 안내 문구, 이미지 로딩 인디케이터 포함.
class ApprovedPostsFeed extends StatefulWidget {
  const ApprovedPostsFeed({super.key});

  @override
  State<ApprovedPostsFeed> createState() => _ApprovedPostsFeedState();
}

class _ApprovedPostsFeedState extends State<ApprovedPostsFeed> {
  int _retryKey = 0; // 재시도 시 스트림 재구독을 위한 키

  void _retry() {
    setState(() {
      _retryKey++;
      // 스트림 캐시 리셋 및 재초기화
      clearApprovedPostsStreamCache();
      initializeApprovedPostsStream(force: true);
      debugPrint('[SYSTEM] : 피드 스트림 재시도 버튼 클릭 - 키: $_retryKey');
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      key: ValueKey(_retryKey), // 재시도 시 스트림 재구독
      stream: _approvedPostsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('[SYSTEM] : 피드 스트림 에러: ${snapshot.error}');
          // 에러 발생 시 재시도 버튼 제공
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '목록을 불러오는 중 오류가 발생했습니다.',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _retry,
                  child: const Text('다시 시도'),
                ),
              ],
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
class ApprovedPostsFeedSliver extends StatefulWidget {
  const ApprovedPostsFeedSliver({super.key});

  @override
  State<ApprovedPostsFeedSliver> createState() => _ApprovedPostsFeedSliverState();
}

class _ApprovedPostsFeedSliverState extends State<ApprovedPostsFeedSliver> {
  int _retryKey = 0; // 재시도 시 스트림 재구독을 위한 키
  bool _loadTimeout = false; // 3초 타임아웃 시 true
  Timer? _timeoutTimer;

  void _retry() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    setState(() {
      _retryKey++;
      _loadTimeout = false;
      clearApprovedPostsStreamCache();
      initializeApprovedPostsStream(force: true);
      debugPrint('[SYSTEM] : 피드 스트림(Sliver) 재시도 버튼 클릭 - 키: $_retryKey');
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  /// 로딩 타임아웃 시 표시할 UI
  Widget _buildTimeoutRetryUi() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '데이터를 불러올 수 없습니다. 다시 시도해주세요',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _retry,
              child: const Text('새로고침'),
            ),
          ],
        ),
      ),
    );
  }

  /// 스켈레톤 카드 최소 2개 (무한 루프처럼 보이지 않게)
  Widget _buildSkeletonSliver() {
    return SliverPadding(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          _FeedSkeletonCard(),
          _FeedSkeletonCard(),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      key: ValueKey(_retryKey),
      stream: _approvedPostsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          _timeoutTimer?.cancel();
          _timeoutTimer = null;
          debugPrint('[SYSTEM] : 피드 스트림 에러 - ${snapshot.error}');
          debugPrint('[SYSTEM] : 피드 스트림 에러 스택 - ${snapshot.stackTrace}');
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '데이터를 불러올 수 없습니다. 다시 시도해주세요',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _retry,
                    child: const Text('새로고침'),
                  ),
                ],
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          // 3초 타임아웃 타이머
          if (!_loadTimeout) {
            _timeoutTimer?.cancel();
            _timeoutTimer = Timer(const Duration(seconds: 3), () {
              if (mounted) setState(() => _loadTimeout = true);
            });
          }
          if (_loadTimeout) return _buildTimeoutRetryUi();
          return _buildSkeletonSliver();
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
        _timeoutTimer?.cancel();
        _timeoutTimer = null;
        _loadTimeout = false;
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

/// 피드 로딩용 스켈레톤 카드 (무한 루프처럼 보이지 않게 2개만 표시)
class _FeedSkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ShimmerPlaceholder(height: 36, width: 36, borderRadius: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: ShimmerPlaceholder(height: 16, borderRadius: 8),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ShimmerPlaceholder(height: 160, borderRadius: 12),
            const SizedBox(height: 12),
            ShimmerPlaceholder(height: 18, borderRadius: 6),
            const SizedBox(height: 8),
            ShimmerPlaceholder(height: 14, width: 200, borderRadius: 6),
          ],
        ),
      ),
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
