// 목적: 감사 편지 쓰기 — 현재 유저가 작성한 모든 투병 기록 목록. 승인됨+후원금 있는 글만 감사 편지 작성 가능.
// 흐름: PostCreateChoiceScreen [감사 편지 쓰기] → 본 화면 → (승인·후원 있음) 게시물 탭 → ThankYouLetterUploadScreen.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/firestore_keys.dart';
import 'thank_you_letter_upload_screen.dart';

class ThankYouPostListScreen extends StatelessWidget {
  const ThankYouPostListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthRepository.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('감사 편지 쓰기'), backgroundColor: AppColors.yellow),
        body: const Center(child: Text('로그인이 필요합니다.')),
      );
    }

    final userId = user.id.toString();
    // patientId 우선, 없으면 userId/authorId로 쿼리 (필드 일관성)
    final stream = FirebaseFirestore.instance
        .collection(FirestoreCollections.posts)
        .where(FirestorePostKeys.patientId, isEqualTo: userId)
        .orderBy(FirestorePostKeys.createdAt, descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('감사 편지 쓰기'),
        backgroundColor: AppColors.yellow,
        foregroundColor: AppColors.textPrimary,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint('[THANK_YOU_LIST] : 스트림 에러 — ${snapshot.error}');
            return Center(
              child: Text(
                '목록을 불러올 수 없습니다.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          debugPrint('[THANK_YOU_LIST] : 로드된 게시물 수: ${docs.length}');
          if (docs.isNotEmpty) {
            final firstData = docs.first.data() as Map<String, dynamic>? ?? {};
            debugPrint('[THANK_YOU_LIST] : 첫 문서 필드: ${firstData.keys.toList()}, patientId=${firstData[FirestorePostKeys.patientId]}, currentUser.id=$userId');
          }

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '아직 작성한 투병 기록이 없습니다.\n투병 기록을 먼저 작성해 주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.5),
                ),
              ),
            );
          }

          // 필터 없이 모든 docs를 리스트 아이템으로 렌더링 (강제 렌더링)
          final children = <Widget>[];
          for (var i = 0; i < docs.length; i++) {
            children.add(_buildCard(context, docs[i], userId, user.nickname));
            if (i < docs.length - 1) children.add(const SizedBox(height: 12));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: children,
          );
        },
      ),
    );
  }

  Widget _buildCard(BuildContext context, QueryDocumentSnapshot<Object?> doc, String userId, String userNickname) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final title = data[FirestorePostKeys.title]?.toString() ?? '(제목 없음)';
    debugPrint('[LIST_BUILD] : 카드 생성 중 - $title');

    final content = data[FirestorePostKeys.content]?.toString() ?? '';
    final status = data[FirestorePostKeys.status]?.toString() ?? FirestorePostKeys.pending;
    final currentAmount = _toInt(data[FirestorePostKeys.currentAmount]);
    final goalAmount = _toInt(data[FirestorePostKeys.goalAmount]);
    final imageUrls = data[FirestorePostKeys.imageUrls];
    final urls = imageUrls is List ? (imageUrls as List).cast<String>() : <String>[];
    final firstUrl = urls.isNotEmpty ? urls.first : null;

    final canWriteThankYou = status == FirestorePostKeys.approved && currentAmount > 0;

    return _PostCard(
      title: title,
      content: content,
      status: status,
      currentAmount: currentAmount,
      goalAmount: goalAmount,
      firstImageUrl: firstUrl,
      canTap: canWriteThankYou,
      onTap: canWriteThankYou
          ? () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ThankYouLetterUploadScreen(
                    postId: doc.id,
                    postTitle: title,
                    patientId: userId,
                    patientName: userNickname,
                  ),
                ),
              );
            }
          : null,
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v != null) return int.tryParse(v.toString()) ?? 0;
    return 0;
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.title,
    required this.content,
    required this.status,
    required this.currentAmount,
    required this.goalAmount,
    this.firstImageUrl,
    required this.canTap,
    this.onTap,
  });

  final String title;
  final String content;
  final String status;
  final int currentAmount;
  final int goalAmount;
  final String? firstImageUrl;
  final bool canTap;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final statusLabel = status == FirestorePostKeys.approved
        ? '승인됨'
        : status == FirestorePostKeys.rejected
            ? '반려됨'
            : '승인 대기중';
    final statusColor = status == FirestorePostKeys.approved
        ? AppColors.coral
        : status == FirestorePostKeys.rejected
            ? Colors.red.shade700
            : AppColors.textSecondary;

    final cardContent = Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _thumbnail(firstImageUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(
                            statusLabel,
                            style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600),
                          ),
                          backgroundColor: statusColor.withValues(alpha: 0.15),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      content,
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_formatMoney(currentAmount)}원 / ${_formatMoney(goalAmount)}원',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.coral,
                      ),
                    ),
                    if (currentAmount > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '후원자가 함께하고 있습니다',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.coral,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (canTap)
                const Icon(Icons.chevron_right, color: AppColors.textSecondary)
              else
                Icon(Icons.lock_outline, size: 20, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );

    if (canTap) {
      return cardContent;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(
          opacity: 0.5,
          child: cardContent,
        ),
        Positioned(
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '후원금이 모이면 작성할 수 있습니다',
              style: TextStyle(fontSize: 11, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _thumbnail(String? url) {
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.inactiveBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.article_outlined, size: 32, color: AppColors.textSecondary),
    );
  }

  static String _formatMoney(int value) {
    final s = value.toString();
    if (s.length <= 3) return s;
    final buf = StringBuffer();
    var i = s.length % 3;
    if (i == 0) i = 3;
    buf.write(s.substring(0, i));
    for (; i < s.length; i += 3) {
      buf.write(',');
      buf.write(s.substring(i, i + 3));
    }
    return buf.toString();
  }
}
