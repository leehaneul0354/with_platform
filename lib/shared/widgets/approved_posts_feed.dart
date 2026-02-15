// 목적: Firestore 'posts' 중 status=='approved'만 최신순으로 실시간 스트림, 피드 카드 리스트.
// 흐름: 메인 피드 탭 선택 시 MainContentMobile/Desktop에서 사용. 빈 상태·로딩·에러 처리.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/constants/firestore_keys.dart';
import 'story_feed_card.dart';

/// 승인된 사연만 최신순으로 표시하는 피드. 빈 상태 시 안내 문구, 이미지 로딩 인디케이터 포함.
class ApprovedPostsFeed extends StatelessWidget {
  const ApprovedPostsFeed({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('[SYSTEM] : 피드 데이터 로드 중...');
    // Firestore 복합 인덱스 필요: posts 컬렉션 (status, createdAt desc). 에러 시 콘솔 링크로 생성.
    final stream = FirebaseFirestore.instance
        .collection(FirestoreCollections.posts)
        .where(FirestorePostKeys.status, isEqualTo: FirestorePostKeys.approved)
        .orderBy(FirestorePostKeys.createdAt, descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
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
          debugPrint('[SYSTEM] : 피드 데이터 로드 중... (연결 대기)');
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        debugPrint('[SYSTEM] : 피드 데이터 로드 완료 — 승인된 사연 ${docs.length}건');
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
