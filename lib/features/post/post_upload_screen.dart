// 목적: 환자 투병기록 작성. 제목·내용·사진 필수 검증, ImgBB 업로드 후 Firestore posts 저장.
// 흐름: PostCreateChoiceScreen → 본 화면 → [사진 업로드 → URL 확보 → Firestore 저장] 한 번에 로딩.
// 환자 본인의 기록을 작성하므로 patientId는 현재 로그인 사용자로 자동 할당됨.

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/firestore_keys.dart';
import '../../core/services/imgbb_upload.dart';

class PostUploadScreen extends StatefulWidget {
  const PostUploadScreen({super.key});

  @override
  State<PostUploadScreen> createState() => _PostUploadScreenState();
}

class _PostUploadScreenState extends State<PostUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _goalAmountController = TextEditingController();
  final _neededItemsController = TextEditingController();
  final _usagePurposeController = TextEditingController();
  final List<XFile> _pickedFiles = [];
  bool _isSubmitting = false;
  String _fundingType = FirestorePostKeys.fundingTypeMoney;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _goalAmountController.dispose();
    _neededItemsController.dispose();
    _usagePurposeController.dispose();
    super.dispose();
  }


  static const int _maxImages = 3;

  Future<void> _pickImages() async {
    if (_pickedFiles.length >= _maxImages) return;
    try {
      debugPrint('[SYSTEM] : 사진 선택 시작');
      final picker = ImagePicker();
      final list = await picker.pickMultiImage();
      if (list.isEmpty) return;
      setState(() {
        for (final f in list) {
          if (_pickedFiles.length >= _maxImages) break;
          _pickedFiles.add(f);
        }
      });
      debugPrint('[SYSTEM] : 사진 추가, 총 ${_pickedFiles.length}장');
    } catch (e) {
      debugPrint('[SYSTEM] : 사진 선택 오류 $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사진 선택 중 오류: $e')),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() => _pickedFiles.removeAt(index));
    debugPrint('[SYSTEM] : 사진 1장 제거, 남은 ${_pickedFiles.length}장');
  }

  Widget _placeholder() => Container(
        color: Colors.grey.shade300,
        child: const Icon(Icons.image_not_supported),
      );

  bool get _canSubmit {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty || content.length < 20 || _isSubmitting) return false;
    if (_fundingType == FirestorePostKeys.fundingTypeMoney) {
      final goal = int.tryParse(_goalAmountController.text.trim());
      return goal != null && goal > 0;
    }
    return _neededItemsController.text.trim().isNotEmpty;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = AuthRepository.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    debugPrint('[SYSTEM] : 게시물 업로드 시작 (제목·이미지 업로드·Firestore 저장)');

    try {
      final imageUrls = <String>[];
      for (var i = 0; i < _pickedFiles.length; i++) {
        final url = await uploadImageToImgBB(_pickedFiles[i]);
        if (url != null) {
          imageUrls.add(url);
        } else {
          debugPrint('[SYSTEM] : 이미지 ${i + 1}번 ImgBB 업로드 실패');
        }
      }
      if (_pickedFiles.isNotEmpty && imageUrls.isEmpty) {
        setState(() => _isSubmitting = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('이미지 업로드에 실패했습니다. 다시 시도해 주세요.')),
          );
        }
        return;
      }

      final isMoney = _fundingType == FirestorePostKeys.fundingTypeMoney;
      final goalAmount = isMoney ? (int.tryParse(_goalAmountController.text.trim()) ?? 0) : 0;
      final neededItemsStr = isMoney ? '' : _neededItemsController.text.trim();

      final postData = <String, dynamic>{
        FirestorePostKeys.title: _titleController.text.trim(),
        FirestorePostKeys.content: _contentController.text.trim(),
        FirestorePostKeys.imageUrls: imageUrls,
        FirestorePostKeys.patientId: user.id,
        FirestorePostKeys.patientName: user.nickname,
        FirestorePostKeys.createdAt: FieldValue.serverTimestamp(),
        FirestorePostKeys.status: FirestorePostKeys.pending,
        FirestorePostKeys.type: FirestorePostKeys.typeStruggle,
        FirestorePostKeys.fundingType: _fundingType,
        FirestorePostKeys.goalAmount: goalAmount,
        FirestorePostKeys.neededItems: neededItemsStr,
        FirestorePostKeys.usagePurpose: _usagePurposeController.text.trim(),
        FirestorePostKeys.currentAmount: 0,
      };

      final ref = FirebaseFirestore.instance.collection(FirestoreCollections.posts).doc();
      await ref.set(postData);
      debugPrint('[SYSTEM] : Firestore 게시물 저장 완료 docId=${ref.id}');

      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('검토 후 업로드됩니다.')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('[SYSTEM] : 게시물 업로드 예외 $e');
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 중 오류: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('투병기록 남기기'),
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
                      hintText: '20자 이상 작성해 주세요',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                    maxLines: null,
                    minLines: 10,
                    validator: (v) {
                      if (v == null || v.trim().length < 20) {
                        return '내용은 20자 이상 입력해주세요';
                      }
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 20),
                  const Text('후원 유형', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Radio<String>(
                        value: FirestorePostKeys.fundingTypeMoney,
                        groupValue: _fundingType,
                        onChanged: (v) => setState(() => _fundingType = v!),
                      ),
                      const Text('후원금'),
                      const SizedBox(width: 16),
                      Radio<String>(
                        value: FirestorePostKeys.fundingTypeGoods,
                        groupValue: _fundingType,
                        onChanged: (v) => setState(() => _fundingType = v!),
                      ),
                      const Text('후원물품'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _usagePurposeController,
                    decoration: const InputDecoration(
                      labelText: '후원 사용 목적 (선택)',
                      hintText: '예: 치료비, 간병비, 재활비, 보조기구 구입',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_fundingType == FirestorePostKeys.fundingTypeMoney) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _goalAmountController,
                      decoration: const InputDecoration(
                        labelText: '목표 금액 (원)',
                        hintText: '예: 5000000',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (_fundingType != FirestorePostKeys.fundingTypeMoney) return null;
                        final n = int.tryParse(v?.trim() ?? '');
                        if (n == null || n <= 0) return '목표 금액을 입력해주세요';
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                  if (_fundingType == FirestorePostKeys.fundingTypeGoods) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _neededItemsController,
                      decoration: const InputDecoration(
                        labelText: '필요 물품 리스트',
                        hintText: '필요한 물품을 입력해주세요 (예: 밴드, 거즈, 소독약)',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      validator: (v) {
                        if (_fundingType != FirestorePostKeys.fundingTypeGoods) return null;
                        if (v == null || v.trim().isEmpty) return '필요 물품을 입력해주세요';
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text('사진 (0~$_maxImages장, 선택 사항)', style: const TextStyle(fontWeight: FontWeight.w600)),
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
                                  if (!snap.hasData) return _placeholder();
                                  return Image.memory(
                                    Uint8List.fromList(snap.data!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _placeholder(),
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
                      backgroundColor: AppColors.yellow,
                      foregroundColor: AppColors.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('신청하기'),
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
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('업로드 및 저장 중...', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
