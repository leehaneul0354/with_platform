// 목적: 승인된 사연 상세. ImgBB 사진 크게 표시, 사연 전문, 후원하기·관리자 시 게시물 삭제.
// 흐름: 메인 피드 카드 탭 → 본 화면 → 관리자면 삭제 버튼 노출 → 컨펌 후 AdminService.deletePost → pop.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/user_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/firestore_keys.dart';
import '../../core/services/admin_service.dart';

class PostDetailScreen extends StatelessWidget {
  const PostDetailScreen({
    super.key,
    required this.postId,
    required this.data,
  });

  final String postId;
  final Map<String, dynamic> data;

  static const Color _deleteRed = Color(0xFFE53935);

  @override
  Widget build(BuildContext context) {
    final isAdmin = AuthRepository.instance.currentUser?.type == UserType.admin ||
        AuthRepository.instance.currentUser?.isAdmin == true;
    debugPrint('[SYSTEM] : PostDetailScreen 빌드 — isAdmin=$isAdmin');
    final title = data[FirestorePostKeys.title]?.toString() ?? '(제목 없음)';
    final content = data[FirestorePostKeys.content]?.toString() ?? '';
    final patientName = data[FirestorePostKeys.patientName]?.toString() ?? '-';
    final imageUrls = data[FirestorePostKeys.imageUrls] is List
        ? (data[FirestorePostKeys.imageUrls] as List).cast<String>()
        : <String>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppColors.yellow,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (imageUrls.isNotEmpty) ...[
                    for (final url in imageUrls)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            url,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return AspectRatio(
                                aspectRatio: 16 / 9,
                                child: Container(
                                  color: AppColors.inactiveBackground,
                                  child: const Center(
                                    child: SizedBox(
                                      width: 32,
                                      height: 32,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) => Container(
                              height: 200,
                              color: AppColors.inactiveBackground,
                              child: const Center(
                                child: Icon(Icons.broken_image, size: 48, color: AppColors.textSecondary),
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '작성자: $patientName',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          content,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textPrimary,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 52,
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('서비스 준비 중')),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.coral,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('후원하기', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  if (isAdmin) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 48,
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          debugPrint('[SYSTEM] : [ADMIN] 메인 상세에서 게시물 삭제 요청 — postId=$postId');
                          final confirm = await showDeletePostConfirmDialog(context);
                          if (!confirm) return;
                          final ok = await deletePost(postId);
                          if (!context.mounted) return;
                          if (ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('게시물이 삭제되었습니다')),
                            );
                            Navigator.of(context).pop();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('삭제할 수 없습니다. 권한을 확인해 주세요.')),
                            );
                          }
                        },
                        icon: const Icon(Icons.delete_outline, size: 20),
                        label: const Text('게시물 삭제'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _deleteRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
