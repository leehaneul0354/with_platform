// 목적: 환자 전용 콘텐츠 관리 대시보드. 투병 기록과 감사 편지를 탭으로 구분하여 표시.
// 흐름: PostCreateChoiceScreen에서 진입 → TabBar로 구분 → Firestore에서 본인 게시물만 실시간 스트림 → 상세 페이지 이동.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/user_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/firestore_keys.dart';
import '../../core/services/comment_service.dart';
import '../../core/services/like_service.dart';
import '../main/thank_you_detail_screen.dart';
import '../post/post_detail_screen.dart';

/// 환자 전용 콘텐츠 관리 대시보드
class PatientMyContentScreen extends StatefulWidget {
  const PatientMyContentScreen({super.key});

  @override
  State<PatientMyContentScreen> createState() => _PatientMyContentScreenState();
}

class _PatientMyContentScreenState extends State<PatientMyContentScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthRepository.instance.currentUser;
    if (user == null || user.type != UserType.patient) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('환자 계정으로 로그인 후 이용할 수 있습니다.')),
        );
        Navigator.of(context).pop();
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '내 게시물 관리',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.coral,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.coral,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: '나의 투병기록'),
            Tab(text: '나의 감사편지'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MyPostsTab(userId: user.id),
          _MyThankYouTab(userId: user.id),
        ],
      ),
    );
  }
}

/// 투병 기록 탭
class _MyPostsTab extends StatelessWidget {
  const _MyPostsTab({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(FirestoreCollections.posts)
          .where(FirestorePostKeys.patientId, isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                  const SizedBox(height: 16),
                  Text(
                    '게시물을 불러오는 중 오류가 발생했습니다.',
                    style: TextStyle(color: Colors.red.shade700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '에러: ${snapshot.error}',
                    style: TextStyle(color: Colors.red.shade400, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.article_outlined, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                Text(
                  '아직 작성한 투병 기록이 없습니다.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        }
        // createdAt 기준으로 정렬 (클라이언트 사이드)
        final sortedDocs = List<QueryDocumentSnapshot>.from(docs);
        sortedDocs.sort((a, b) {
          final aCreatedAt = a.data() as Map<String, dynamic>?;
          final bCreatedAt = b.data() as Map<String, dynamic>?;
          final aTimestamp = aCreatedAt?[FirestorePostKeys.createdAt] as Timestamp?;
          final bTimestamp = bCreatedAt?[FirestorePostKeys.createdAt] as Timestamp?;
          if (aTimestamp == null && bTimestamp == null) return 0;
          if (aTimestamp == null) return 1;
          if (bTimestamp == null) return -1;
          return bTimestamp.compareTo(aTimestamp); // 내림차순
        });
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: sortedDocs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = sortedDocs[index];
            final data = doc.data() as Map<String, dynamic>? ?? {};
            return _PostItemCard(
              postId: doc.id,
              data: data,
              postType: 'post',
            );
          },
        );
      },
    );
  }
}

/// 감사 편지 탭
class _MyThankYouTab extends StatelessWidget {
  const _MyThankYouTab({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(FirestoreCollections.thankYouPosts)
          .where(ThankYouPostKeys.patientId, isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                  const SizedBox(height: 16),
                  Text(
                    '감사 편지를 불러오는 중 오류가 발생했습니다.',
                    style: TextStyle(color: Colors.red.shade700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '에러: ${snapshot.error}',
                    style: TextStyle(color: Colors.red.shade400, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mail_outline, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                Text(
                  '아직 작성한 감사 편지가 없습니다.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        }
        // createdAt 기준으로 정렬 (클라이언트 사이드)
        final sortedDocs = List<QueryDocumentSnapshot>.from(docs);
        sortedDocs.sort((a, b) {
          final aCreatedAt = a.data() as Map<String, dynamic>?;
          final bCreatedAt = b.data() as Map<String, dynamic>?;
          final aTimestamp = aCreatedAt?[ThankYouPostKeys.createdAt] as Timestamp?;
          final bTimestamp = bCreatedAt?[ThankYouPostKeys.createdAt] as Timestamp?;
          if (aTimestamp == null && bTimestamp == null) return 0;
          if (aTimestamp == null) return 1;
          if (bTimestamp == null) return -1;
          return bTimestamp.compareTo(aTimestamp); // 내림차순
        });
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: sortedDocs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = sortedDocs[index];
            final data = doc.data() as Map<String, dynamic>? ?? {};
            return _PostItemCard(
              postId: doc.id,
              data: data,
              postType: 'thank_you',
            );
          },
        );
      },
    );
  }
}

/// 게시물/감사편지 아이템 카드 (좋아요/댓글 수 표시)
class _PostItemCard extends StatelessWidget {
  const _PostItemCard({
    required this.postId,
    required this.data,
    required this.postType,
  });

  final String postId;
  final Map<String, dynamic> data;
  final String postType; // 'post' 또는 'thank_you'

  @override
  Widget build(BuildContext context) {
    // 데이터 필드 안전하게 읽기
    final title = postType == 'thank_you'
        ? (data[ThankYouPostKeys.title]?.toString() ?? '(제목 없음)')
        : (data[FirestorePostKeys.title]?.toString() ?? '(제목 없음)');
    
    // status 필드 안전하게 읽기
    String status = 'pending';
    if (postType == 'thank_you') {
      final statusValue = data[ThankYouPostKeys.status];
      if (statusValue != null) {
        status = statusValue.toString();
      }
    } else {
      final statusValue = data[FirestorePostKeys.status];
      if (statusValue != null) {
        status = statusValue.toString();
      }
    }
    final isApproved = status == 'approved' || status == ThankYouPostKeys.approved;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isApproved ? AppColors.coral.withValues(alpha: 0.3) : AppColors.inactiveBackground,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          if (postType == 'thank_you') {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ThankYouDetailScreen(
                  data: data,
                  todayDocId: null, // 환자 본인 화면에서는 todayDocId 불필요
                ),
              ),
            );
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PostDetailScreen(postId: postId, data: data),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isApproved
                          ? AppColors.coral.withValues(alpha: 0.15)
                          : AppColors.inactiveBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isApproved ? AppColors.coral : AppColors.textSecondary,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      isApproved ? '승인됨' : '대기중',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isApproved ? AppColors.coral : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  StreamBuilder<int>(
                    stream: likeCountStream(postId: postId, postType: postType),
                    builder: (context, snapshot) {
                      final likeCount = snapshot.data ?? 0;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.favorite, size: 16, color: Colors.red.shade400),
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
                  ),
                  const SizedBox(width: 16),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: commentsStream(postId: postId, postType: postType),
                    builder: (context, snapshot) {
                      final commentCount = snapshot.data?.docs.length ?? 0;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 16, color: AppColors.textSecondary),
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
      ),
    );
  }
}
