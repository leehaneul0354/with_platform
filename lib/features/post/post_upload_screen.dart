// 목적: 환자 사연 신청 업로드. 제목·내용·사진 필수 검증, ImgBB 업로드 후 Firestore posts 저장.
// 흐름: 메인 FAB(환자 전용) → 본 화면 → [사진 업로드 → URL 확보 → Firestore 저장] 한 번에 로딩.

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/firestore_keys.dart';
import '../../core/services/imgbb_upload.dart';

class PostUploadScreen extends StatefulWidget {
  const PostUploadScreen({
    super.key,
    this.selectedTargetId,
    this.selectedTargetName,
  });

  final String? selectedTargetId;
  final String? selectedTargetName;

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
  String? _selectedTargetId;
  String? _selectedTargetName;
  List<Map<String, String>> _supportedTargets = [];
  bool _isLoadingTargets = true;

  @override
  void initState() {
    super.initState();
    // PostCreateChoiceScreen에서 선택된 대상이 있으면 사용
    _selectedTargetId = widget.selectedTargetId;
    _selectedTargetName = widget.selectedTargetName;
    _loadSupportedTargets();
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

  /// donations와 comments 컬렉션에서 후원 중인 대상 목록 가져오기
  Future<void> _loadSupportedTargets() async {
    final user = AuthRepository.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoadingTargets = false;
          _supportedTargets = [];
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _isLoadingTargets = true);
    }

    try {
      debugPrint('[POST_UPLOAD] : 후원 대상 목록 로드 시작 - userId: ${user.id}');
      
      // donations에서 후원 내역 가져오기
      final donationsSnapshot = await FirebaseFirestore.instance
          .collection(FirestoreCollections.donations)
          .where(DonationKeys.userId, isEqualTo: user.id)
          .get();

      debugPrint('[POST_UPLOAD] : donations 개수: ${donationsSnapshot.docs.length}');

      final postIds = <String>{};
      for (final doc in donationsSnapshot.docs) {
        final data = doc.data();
        final postId = data[DonationKeys.postId] as String?;
        if (postId != null && postId.isNotEmpty) {
          postIds.add(postId);
        }
      }

      // comments에서도 후원 내역 가져오기
      final commentsSnapshot = await FirebaseFirestore.instance
          .collection(FirestoreCollections.comments)
          .where(CommentKeys.userId, isEqualTo: user.id)
          .get();

      debugPrint('[POST_UPLOAD] : comments 개수: ${commentsSnapshot.docs.length}');

      for (final doc in commentsSnapshot.docs) {
        final data = doc.data();
        final postId = data[CommentKeys.postId] as String?;
        if (postId != null && postId.isNotEmpty) {
          postIds.add(postId);
        }
      }

      debugPrint('[POST_UPLOAD] : 추출된 postIds 개수: ${postIds.length}');

      if (postIds.isEmpty) {
        debugPrint('[POST_UPLOAD] : 후원 내역이 없음');
        if (mounted) {
          setState(() {
            _isLoadingTargets = false;
            _supportedTargets = [];
          });
        }
        return;
      }

      // posts에서 patientId 추출
      final postIdsList = postIds.toList();
      final queryPostIds = postIdsList.length > 10 
          ? postIdsList.take(10).toList() 
          : postIdsList;
      
      final postsSnapshot = await FirebaseFirestore.instance
          .collection(FirestoreCollections.posts)
          .where(FieldPath.documentId, whereIn: queryPostIds)
          .get();

      debugPrint('[POST_UPLOAD] : posts 조회 결과: ${postsSnapshot.docs.length}개');

      final patientIds = <String>{};
      for (final postDoc in postsSnapshot.docs) {
        final postData = postDoc.data();
        final patientId = postData[FirestorePostKeys.patientId] as String?;
        if (patientId != null && patientId.isNotEmpty) {
          patientIds.add(patientId);
        }
      }

      debugPrint('[POST_UPLOAD] : 추출된 patientIds 개수: ${patientIds.length}');

      if (patientIds.isEmpty) {
        debugPrint('[POST_UPLOAD] : patientId가 없음');
        if (mounted) {
          setState(() {
            _isLoadingTargets = false;
            _supportedTargets = [];
          });
        }
        return;
      }

      // 환자 정보 가져오기
      final patientIdsList = patientIds.toList();
      final queryPatientIds = patientIdsList.length > 10 
          ? patientIdsList.take(10).toList() 
          : patientIdsList;
      
      final usersSnapshot = await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .where(FieldPath.documentId, whereIn: queryPatientIds)
          .get();

      debugPrint('[POST_UPLOAD] : users 조회 결과: ${usersSnapshot.docs.length}개');

      final targets = <Map<String, String>>[];
      for (final userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final nickname = userData[FirestoreUserKeys.nickname] as String? ?? '이름없음';
        targets.add({
          'id': userDoc.id,
          'name': nickname,
        });
        debugPrint('[POST_UPLOAD] : 환자 추가 - id: ${userDoc.id}, name: $nickname');
      }

      debugPrint('[POST_UPLOAD] : 최종 후원 대상 개수: ${targets.length}');

      if (mounted) {
        setState(() {
          _isLoadingTargets = false;
          _supportedTargets = targets;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('[POST_UPLOAD] : 후원 대상 목록 로드 오류: $e');
      debugPrint('[POST_UPLOAD] : 스택 트레이스: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoadingTargets = false;
          _supportedTargets = [];
        });
      }
    }
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

      // 후원 대상이 선택된 경우 추가 정보 포함
      if (_selectedTargetId != null && _selectedTargetName != null) {
        postData['targetId'] = _selectedTargetId;
        postData['targetName'] = _selectedTargetName;
        debugPrint('[SYSTEM] : 후원 대상 선택됨 - ID: $_selectedTargetId, 이름: $_selectedTargetName');
      }

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
        title: const Text('환자 사연 신청'),
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
                  // 후원 대상 선택 섹션
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.inactiveBackground.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.textSecondary.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.person_outline, size: 20, color: AppColors.textPrimary),
                            SizedBox(width: 8),
                            Text(
                              '사연의 주인공을 선택해주세요',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_isLoadingTargets)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          )
                        else if (_supportedTargets.isNotEmpty) ...[
                          // 가로형 환자 리스트
                          SizedBox(
                            height: 100,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _supportedTargets.length + 1, // +1 for "일반 사연"
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  // 일반 사연 옵션
                                  final isSelected = _selectedTargetId == null;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _selectedTargetId = null;
                                          _selectedTargetName = null;
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        width: 80,
                                        decoration: BoxDecoration(
                                          color: isSelected ? AppColors.yellow.withValues(alpha: 0.3) : Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isSelected 
                                                ? AppColors.yellow 
                                                : AppColors.textSecondary.withValues(alpha: 0.2),
                                            width: isSelected ? 2 : 1,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.description_outlined,
                                              size: 32,
                                              color: isSelected ? AppColors.yellow : AppColors.textSecondary,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              '일반 사연',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                
                                final target = _supportedTargets[index - 1];
                                final isSelected = _selectedTargetId == target['id'];
                                return Padding(
                                  padding: EdgeInsets.only(right: index == _supportedTargets.length ? 0 : 12),
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _selectedTargetId = target['id'];
                                        _selectedTargetName = target['name'];
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: 80,
                                      decoration: BoxDecoration(
                                        color: isSelected ? AppColors.coral.withValues(alpha: 0.2) : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected 
                                              ? AppColors.coral 
                                              : AppColors.textSecondary.withValues(alpha: 0.2),
                                          width: isSelected ? 2 : 1,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          CircleAvatar(
                                            radius: 24,
                                            backgroundColor: AppColors.coral.withValues(alpha: 0.2),
                                            child: Text(
                                              (target['name']?.isNotEmpty ?? false) 
                                                  ? target['name']![0].toUpperCase() 
                                                  : '?',
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.coral,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 4),
                                            child: Text(
                                              target['name'] ?? '이름없음',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                                color: AppColors.textPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          // 선택된 대상 표시
                          if (_selectedTargetId != null && _selectedTargetName != null)
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.coral.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, size: 16, color: AppColors.coral),
                                  const SizedBox(width: 8),
                                  Text(
                                    '선택됨: $_selectedTargetName',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.inactiveBackground,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 20,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '후원 중인 대상이 없습니다. 일반 사연으로 등록됩니다.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
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
