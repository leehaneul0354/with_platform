// 목적: 후원자가 선택한 환자의 투병기록/감사편지 목록 조회 화면.
// 흐름: PostCreateChoiceScreen → 환자 선택 → 본 화면 → 투병기록/감사편지 탭으로 구분 → 상세 페이지 이동.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/assets.dart';
import '../../core/constants/firestore_keys.dart';
import '../../core/services/comment_service.dart';
import '../../core/services/like_service.dart';
import '../main/thank_you_detail_screen.dart';
import '../post/post_detail_screen.dart';

/// 후원자가 선택한 환자의 기록 목록 화면
class PatientPostsListScreen extends StatefulWidget {
  const PatientPostsListScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  final String patientId;
  final String patientName;

  @override
  State<PatientPostsListScreen> createState() => _PatientPostsListScreenState();
}

class _PatientPostsListScreenState extends State<PatientPostsListScreen> with SingleTickerProviderStateMixin {
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.patientName,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '소중한 기록',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary.withValues(alpha: 0.6),
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.normal,
          ),
          tabs: const [
            Tab(text: '투병기록'),
            Tab(text: '감사편지'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PatientPostsTab(patientId: widget.patientId, patientName: widget.patientName),
          _PatientThankYouTab(patientId: widget.patientId, patientName: widget.patientName),
        ],
      ),
    );
  }
}

/// 투병 기록 탭
class _PatientPostsTab extends StatelessWidget {
  const _PatientPostsTab({
    required this.patientId,
    required this.patientName,
  });

  final String patientId;
  final String patientName;

  @override
  Widget build(BuildContext context) {
    // 복합 인덱스가 없을 수 있으므로, 먼저 where만 사용하고 클라이언트에서 정렬
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(FirestoreCollections.posts)
          .where(FirestorePostKeys.patientId, isEqualTo: patientId)
          .where(FirestorePostKeys.status, isEqualTo: FirestorePostKeys.approved)
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
                    '투병 기록을 불러오는 중 오류가 발생했습니다.',
                    style: TextStyle(color: Colors.red.shade700),
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
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    WithMascots.withMascot,
                    width: 64,
                    height: 64,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.article_outlined,
                      size: 64,
                      color: AppColors.textSecondary.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '아직 등록된 소식이 없습니다.',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$patientName님의 소식을 기다리고 있어요.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        // createdAt 기준으로 정렬 (클라이언트 사이드)
        final sortedDocs = List<QueryDocumentSnapshot>.from(docs);
        sortedDocs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>?;
          final bData = b.data() as Map<String, dynamic>?;
          final aTimestamp = aData?[FirestorePostKeys.createdAt] as Timestamp?;
          final bTimestamp = bData?[FirestorePostKeys.createdAt] as Timestamp?;
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
class _PatientThankYouTab extends StatelessWidget {
  const _PatientThankYouTab({
    required this.patientId,
    required this.patientName,
  });

  final String patientId;
  final String patientName;

  @override
  Widget build(BuildContext context) {
    // 복합 인덱스가 없을 수 있으므로, 먼저 where만 사용하고 클라이언트에서 정렬
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(FirestoreCollections.thankYouPosts)
          .where(ThankYouPostKeys.patientId, isEqualTo: patientId)
          .where(ThankYouPostKeys.status, isEqualTo: ThankYouPostKeys.approved)
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
                ],
              ),
            ),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    WithMascots.withMascot,
                    width: 64,
                    height: 64,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.mail_outline,
                      size: 64,
                      color: AppColors.textSecondary.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '아직 등록된 소식이 없습니다.',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$patientName님의 소식을 기다리고 있어요.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        // createdAt 기준으로 정렬 (클라이언트 사이드)
        final sortedDocs = List<QueryDocumentSnapshot>.from(docs);
        sortedDocs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>?;
          final bData = b.data() as Map<String, dynamic>?;
          final aTimestamp = aData?[ThankYouPostKeys.createdAt] as Timestamp?;
          final bTimestamp = bData?[ThankYouPostKeys.createdAt] as Timestamp?;
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

/// 게시물/감사편지 아이템 카드
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
    final title = postType == 'thank_you'
        ? (data[ThankYouPostKeys.title]?.toString() ?? '(제목 없음)')
        : (data[FirestorePostKeys.title]?.toString() ?? '(제목 없음)');
    
    final content = postType == 'thank_you'
        ? (data[ThankYouPostKeys.content]?.toString() ?? '')
        : (data[FirestorePostKeys.content]?.toString() ?? '');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.coral.withValues(alpha: 0.2),
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
                  todayDocId: null,
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
        borderRadius: BorderRadius.circular(16),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.coral.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      postType == 'thank_you' ? '감사편지' : '투병기록',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.coral,
                      ),
                    ),
                  ),
                ],
              ),
              if (content.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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
