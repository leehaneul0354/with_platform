// 목적: 어드민 게시물 작성·관리 — 정부 정책/기업 광고/플랫폼 소식. 탐색 탭 배너용.
// 흐름: 카테고리 선택 → imgbb 이미지 업로드 → 제목·내용·링크·배지 입력 → 등록. 리스트에서 삭제 가능.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/firestore_keys.dart';
import '../../core/services/admin_post_service.dart';
import '../../core/services/imgbb_upload.dart';

/// 카테고리 옵션 (type 값, 표시 라벨)
const List<({String value, String label})> _typeOptions = [
  (value: AdminPostKeys.typeGovernment, label: '정부 정책'),
  (value: AdminPostKeys.typeAd, label: '기업 광고'),
  (value: AdminPostKeys.typePlatform, label: '플랫폼 소식'),
];

class AdminPostManagementSection extends StatefulWidget {
  const AdminPostManagementSection({super.key});

  @override
  State<AdminPostManagementSection> createState() => _AdminPostManagementSectionState();
}

class _AdminPostManagementSectionState extends State<AdminPostManagementSection> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _linkUrlController = TextEditingController();
  final _badgeTextController = TextEditingController();

  String _selectedType = AdminPostKeys.typeGovernment;
  XFile? _pickedImage;
  String? _uploadedImageUrl;
  bool _isSubmitting = false;
  bool _isUploadingImage = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _linkUrlController.dispose();
    _badgeTextController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (x == null || !mounted) return;
      setState(() {
        _pickedImage = x;
        _uploadedImageUrl = null;
        _isUploadingImage = true;
      });
      final url = await uploadImageToImgBB(x);
      if (mounted) {
        setState(() {
          _uploadedImageUrl = url;
          _isUploadingImage = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 선택/업로드 실패: $e')),
        );
      }
    }
  }

  void _clearImage() {
    setState(() {
      _pickedImage = null;
      _uploadedImageUrl = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목과 내용은 필수입니다.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await addAdminPost(
        type: _selectedType,
        title: title,
        content: content,
        imageUrl: _uploadedImageUrl,
        linkUrl: _linkUrlController.text.trim().isEmpty ? null : _linkUrlController.text.trim(),
        badgeText: _badgeTextController.text.trim().isEmpty ? null : _badgeTextController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('게시물이 등록되었습니다.'),
          backgroundColor: Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _resetForm();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('등록 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _resetForm() {
    _titleController.clear();
    _contentController.clear();
    _linkUrlController.clear();
    _badgeTextController.clear();
    setState(() {
      _selectedType = AdminPostKeys.typeGovernment;
      _pickedImage = null;
      _uploadedImageUrl = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildForm(),
          const SizedBox(height: 32),
          _buildList(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(Icons.campaign_outlined, size: 28, color: AppColors.coral),
        const SizedBox(width: 12),
        const Text(
          '어드민 게시물 관리',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '새 게시물 작성',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 20),
            // 카테고리
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: '카테고리',
                border: OutlineInputBorder(),
              ),
              items: _typeOptions
                  .map((o) => DropdownMenuItem(value: o.value, child: Text(o.label)))
                  .toList(),
              onChanged: _isSubmitting ? null : (v) => setState(() => _selectedType = v ?? AdminPostKeys.typeGovernment),
            ),
            const SizedBox(height: 16),
            // 이미지 업로드
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _isSubmitting || _isUploadingImage ? null : _pickAndUploadImage,
                  icon: _isUploadingImage
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_photo_alternate_outlined, size: 20),
                  label: Text(_isUploadingImage ? '업로드 중...' : '이미지 업로드 (imgbb)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: BorderSide(color: AppColors.textSecondary.withValues(alpha: 0.5)),
                  ),
                ),
                if (_uploadedImageUrl != null) ...[
                  const SizedBox(width: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _uploadedImageUrl!,
                      width: 80,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isSubmitting ? null : _clearImage,
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '제목',
                hintText: '정책명 또는 광고 문구',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? '제목을 입력해 주세요.' : null,
              enabled: !_isSubmitting,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: '내용',
                hintText: '상세 설명',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              validator: (v) => (v == null || v.trim().isEmpty) ? '내용을 입력해 주세요.' : null,
              enabled: !_isSubmitting,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _linkUrlController,
              decoration: const InputDecoration(
                labelText: '외부 링크 (선택)',
                hintText: 'https://...',
                border: OutlineInputBorder(),
              ),
              enabled: !_isSubmitting,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _badgeTextController,
              decoration: const InputDecoration(
                labelText: '배지 텍스트 (선택)',
                hintText: '예: 00정책 지원 복지',
                border: OutlineInputBorder(),
              ),
              enabled: !_isSubmitting,
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.coral,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('등록하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '등록된 게시물',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: adminPostsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text('목록 로드 실패: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
              );
            }
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '등록된 게시물이 없습니다.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final d = doc.data();
                return _AdminPostCard(
                  docId: doc.id,
                  type: d[AdminPostKeys.type]?.toString() ?? '',
                  title: d[AdminPostKeys.title]?.toString() ?? '',
                  content: d[AdminPostKeys.content]?.toString() ?? '',
                  imageUrl: d[AdminPostKeys.imageUrl]?.toString(),
                  linkUrl: d[AdminPostKeys.linkUrl]?.toString(),
                  badgeText: d[AdminPostKeys.badgeText]?.toString(),
                  createdAt: d[AdminPostKeys.createdAt] is Timestamp
                      ? (d[AdminPostKeys.createdAt] as Timestamp).toDate()
                      : null,
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _AdminPostCard extends StatelessWidget {
  const _AdminPostCard({
    required this.docId,
    required this.type,
    required this.title,
    required this.content,
    this.imageUrl,
    this.linkUrl,
    this.badgeText,
    this.createdAt,
  });

  final String docId;
  final String type;
  final String title;
  final String content;
  final String? imageUrl;
  final String? linkUrl;
  final String? badgeText;
  final DateTime? createdAt;

  String get _typeLabel {
    switch (type) {
      case AdminPostKeys.typeGovernment:
        return '정부 정책';
      case AdminPostKeys.typeAd:
        return '기업 광고';
      case AdminPostKeys.typePlatform:
        return '플랫폼 소식';
      default:
        return type;
    }
  }

  String get _formattedDate {
    if (createdAt == null) return '-';
    return '${createdAt!.year}.${createdAt!.month.toString().padLeft(2, '0')}.${createdAt!.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.inactiveBackground),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl != null && imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl!,
                width: 100,
                height: 70,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 100,
                  height: 70,
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.image_not_supported),
                ),
              ),
            ),
          if (imageUrl != null && imageUrl!.isNotEmpty) const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.coral.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _typeLabel,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.coral),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(_formattedDate, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    if (badgeText != null && badgeText!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        badgeText!,
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (linkUrl != null && linkUrl!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '링크: $linkUrl',
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () => _confirmDelete(context),
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
            tooltip: '삭제',
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('게시물 삭제'),
        content: Text('"$title" 게시물을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('취소')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      try {
        await deleteAdminPost(docId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('삭제되었습니다.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('삭제 실패: $e')),
          );
        }
      }
    }
  }
}
