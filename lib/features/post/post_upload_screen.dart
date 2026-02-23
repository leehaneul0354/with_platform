// 목적: 환자 투병기록 작성. [일반 기록]과 [후원 요청] 모드 분리, Firebase Storage 업로드 후 Firestore 저장.
// 흐름: PostCreateChoiceScreen → 본 화면 → 상단 모드 선택 → 제목·내용·(후원 시 추가 필드)·사진 → Storage 업로드 → posts 저장.

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/firestore_keys.dart';
import '../../core/services/post_storage_service.dart';
import '../../shared/widgets/brand_placeholder.dart';

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
  final _hospitalNameController = TextEditingController();
  final _deliveryInfoController = TextEditingController();
  final _goodsQuantityController = TextEditingController();
  final List<XFile> _pickedFiles = [];
  bool _isSubmitting = false;
  /// true: 후원 요청, false: 일반 기록 (기본값)
  bool _isDonationRequest = false;
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
    _hospitalNameController.dispose();
    _deliveryInfoController.dispose();
    _goodsQuantityController.dispose();
    super.dispose();
  }

  static const int _maxImages = 3;

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
          SnackBar(content: Text('사진 선택 중 오류: $e')),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() => _pickedFiles.removeAt(index));
  }

  Widget _imagePlaceholder() => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: BrandPlaceholder(
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          emoji: _isDonationRequest ? '🤝' : '📄',
          borderRadius: BorderRadius.circular(8),
        ),
      );

  bool get _canSubmit {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty || content.length < 20 || _isSubmitting) return false;
    if (!_isDonationRequest) return true;
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

    try {
      final imageUrls = <String>[];

      // 이미지가 있는 경우: 하나라도 실패하면 전체 업로드/저장 취소 (트랜잭션처럼 동작)
      if (_pickedFiles.isNotEmpty) {
        bool uploadFailed = false;
        for (var i = 0; i < _pickedFiles.length; i++) {
          final url = await uploadPostImage(_pickedFiles[i]);
          if (url == null) {
            uploadFailed = true;
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('이미지 업로드에 실패했습니다. 다시 시도해 주세요. (이미지 ${i + 1})')),
              );
            }
            break;
          }
          imageUrls.add(url);
        }
        if (uploadFailed) {
          setState(() => _isSubmitting = false);
          return;
        }
      }

      final isMoney = _fundingType == FirestorePostKeys.fundingTypeMoney;
      final goalAmount = _isDonationRequest && isMoney
          ? (int.tryParse(_goalAmountController.text.trim()) ?? 0)
          : 0;
      final neededItemsStr = _isDonationRequest && !isMoney
          ? _neededItemsController.text.trim()
          : '';
      final usagePurpose = _isDonationRequest ? _usagePurposeController.text.trim() : '';
      final hospitalName = _isDonationRequest && isMoney ? _hospitalNameController.text.trim() : '';
      final deliveryInfo = _isDonationRequest && !isMoney ? _deliveryInfoController.text.trim() : '';
      final goodsQuantity = _isDonationRequest && !isMoney ? _goodsQuantityController.text.trim() : '';

      final postData = <String, dynamic>{
        FirestorePostKeys.title: _titleController.text.trim(),
        FirestorePostKeys.content: _contentController.text.trim(),
        FirestorePostKeys.imageUrls: imageUrls,
        FirestorePostKeys.patientId: user.id,
        FirestorePostKeys.patientName: user.nickname,
        FirestorePostKeys.createdAt: FieldValue.serverTimestamp(),
        FirestorePostKeys.status: FirestorePostKeys.pending,
        FirestorePostKeys.type: FirestorePostKeys.typeStruggle,
        FirestorePostKeys.isDonationRequest: _isDonationRequest,
        FirestorePostKeys.fundingType: _isDonationRequest ? _fundingType : FirestorePostKeys.fundingTypeMoney,
        FirestorePostKeys.goalAmount: goalAmount,
        FirestorePostKeys.neededItems: neededItemsStr,
        FirestorePostKeys.usagePurpose: usagePurpose,
        FirestorePostKeys.currentAmount: 0,
      };
      if (_isDonationRequest) {
        if (hospitalName.isNotEmpty) postData[FirestorePostKeys.hospitalName] = hospitalName;
        if (deliveryInfo.isNotEmpty) postData[FirestorePostKeys.deliveryInfo] = deliveryInfo;
        if (goodsQuantity.isNotEmpty) postData[FirestorePostKeys.goodsQuantity] = goodsQuantity;
      }

      final ref = FirebaseFirestore.instance.collection(FirestoreCollections.posts).doc();
      await ref.set(postData);

      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('검토 후 업로드됩니다.')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
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
                  // 상단 모드 선택
                  const Text('작성 모드', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('일반 기록'), icon: Icon(Icons.edit_note)),
                      ButtonSegment(value: true, label: Text('후원 요청'), icon: Icon(Icons.volunteer_activism)),
                    ],
                    selected: {_isDonationRequest},
                    onSelectionChanged: (Set<bool> selected) {
                      setState(() => _isDonationRequest = selected.first);
                    },
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
                      hintText: '20자 이상 작성해 주세요',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                    maxLines: null,
                    minLines: 8,
                    validator: (v) {
                      if (v == null || v.trim().length < 20) return '내용은 20자 이상 입력해주세요';
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                  // 후원 요청 시에만 노출
                  if (_isDonationRequest) ...[
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
                        controller: _hospitalNameController,
                        decoration: const InputDecoration(
                          labelText: '병원명 (선택)',
                          hintText: '예: ○○대학교병원',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.yellow.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.yellow.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 20, color: AppColors.textPrimary),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'WITH Pay로 후원금을 받을 수 있습니다. 승인 후 후원하기 버튼이 노출됩니다.',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
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
                          labelText: '필요 물품명',
                          hintText: '예: 밴드, 거즈, 소독약',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                        validator: (v) {
                          if (_fundingType != FirestorePostKeys.fundingTypeGoods) return null;
                          if (v == null || v.trim().isEmpty) return '필요 물품을 입력해주세요';
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _goodsQuantityController,
                        decoration: const InputDecoration(
                          labelText: '수량 (선택)',
                          hintText: '예: 2박스, 10개',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _deliveryInfoController,
                        decoration: const InputDecoration(
                          labelText: '배송 정보',
                          hintText: '수령 주소·연락처 등 (비공개로 관리됩니다)',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ],
                  const SizedBox(height: 20),
                  Text('사진 (0~$_maxImages장, 선택)', style: const TextStyle(fontWeight: FontWeight.w600)),
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
                                  if (!snap.hasData) return _imagePlaceholder();
                                  return Image.memory(
                                    Uint8List.fromList(snap.data!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _imagePlaceholder(),
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
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 80,
                                  height: 80,
                                  child: BrandPlaceholder(
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    emoji: _isDonationRequest ? '🤝' : '📄',
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              Icon(Icons.add_photo_alternate, size: 28, color: AppColors.textSecondary.withValues(alpha: 0.8)),
                            ],
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
                    child: Text(_isDonationRequest ? '신청하기' : '기록 남기기'),
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
