// 목적: 특정 투병 기록에 대한 감사 편지 작성. 제목·내용·사진(0~3장) → thank_you_posts 저장, status pending.
// 흐름: ThankYouPostListScreen에서 게시물 선택 → 본 화면 → [등록] → "검토 후 업로드됩니다."

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/firestore_keys.dart';
import '../../core/services/imgbb_upload.dart';

class ThankYouLetterUploadScreen extends StatefulWidget {
  const ThankYouLetterUploadScreen({
    super.key,
    required this.postId,
    required this.postTitle,
    required this.patientId,
    required this.patientName,
  });

  final String postId;
  final String postTitle;
  final String patientId;
  final String patientName;

  @override
  State<ThankYouLetterUploadScreen> createState() => _ThankYouLetterUploadScreenState();
}

class _ThankYouLetterUploadScreenState extends State<ThankYouLetterUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final List<XFile> _pickedFiles = [];
  bool _isSubmitting = false;

  static const int _maxImages = 3;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_pickedFiles.length >= _maxImages) return;
    try {
      final picker = ImagePicker();
      final list = await picker.pickMultiImage();
      if (list.isEmpty) return;
      setState(() {
        for (final f in list) {
          if (_pickedFiles.length >= _maxImages) break;
          _pickedFiles.add(f);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사진 선택 오류: $e')),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() => _pickedFiles.removeAt(index));
  }

  bool get _canSubmit {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    return title.isNotEmpty && content.isNotEmpty && !_isSubmitting;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final imageUrls = <String>[];
      for (final file in _pickedFiles) {
        final url = await uploadImageToImgBB(file);
        if (url != null) imageUrls.add(url);
      }

      await FirebaseFirestore.instance.collection(FirestoreCollections.thankYouPosts).add({
        ThankYouPostKeys.title: _titleController.text.trim(),
        ThankYouPostKeys.content: _contentController.text.trim(),
        ThankYouPostKeys.imageUrls: imageUrls,
        ThankYouPostKeys.patientId: widget.patientId,
        ThankYouPostKeys.patientName: widget.patientName,
        ThankYouPostKeys.postId: widget.postId,
        ThankYouPostKeys.postTitle: widget.postTitle,
        ThankYouPostKeys.createdAt: FieldValue.serverTimestamp(),
        ThankYouPostKeys.status: ThankYouPostKeys.pending,
        ThankYouPostKeys.type: FirestorePostKeys.typeThanks,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('검토 후 업로드됩니다.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 중 오류: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('감사 편지 쓰기'),
        backgroundColor: AppColors.yellow,
        foregroundColor: AppColors.textPrimary,
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.yellow.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '대상: ${widget.postTitle}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: '제목',
                      hintText: '제목을 입력해주세요',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return '제목을 입력해주세요';
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _contentController,
                    decoration: const InputDecoration(
                      labelText: '내용',
                      hintText: '감사한 마음을 전해주세요',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                    maxLines: null,
                    minLines: 6,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return '내용을 입력해주세요';
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '사진 (0~$_maxImages장, 선택 사항)',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...List.generate(_pickedFiles.length, (i) {
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            SizedBox(
                              width: 80,
                              height: 80,
                              child: FutureBuilder<List<int>>(
                                future: _pickedFiles[i].readAsBytes(),
                                builder: (context, snap) {
                                  if (!snap.hasData) {
                                    return Container(
                                      color: Colors.grey.shade300,
                                      child: const Icon(Icons.image),
                                    );
                                  }
                                  return Image.memory(
                                    Uint8List.fromList(snap.data!),
                                    fit: BoxFit.cover,
                                  );
                                },
                              ),
                            ),
                            Positioned(
                              top: -6,
                              right: -6,
                              child: GestureDetector(
                                onTap: () => _removeImage(i),
                                child: const CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.red,
                                  child: Icon(Icons.close, size: 18, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                      if (_pickedFiles.length < _maxImages)
                        GestureDetector(
                          onTap: _isSubmitting ? null : _pickImages,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.textSecondary),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.add_photo_alternate, size: 32),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _canSubmit ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.coral,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('등록하기'),
                  ),
                ],
              ),
            ),
          ),
          if (_isSubmitting)
            Container(
              color: Colors.black26,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('저장 중...', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
