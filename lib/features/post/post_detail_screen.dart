// 목적: 승인된 사연 상세. 후원하기 → 금액 선택 다이얼로그 → processPayment → 로딩 오버레이.
// 흐름: 메인 피드 카드 탭 → 본 화면 → 관리자면 삭제 버튼 노출.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/user_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/firestore_keys.dart';
import '../../core/services/admin_service.dart';
import '../../core/services/donation_service.dart';
import '../../core/services/with_pay_service.dart';
import '../main/with_pay_recharge_dialog.dart';

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({
    super.key,
    required this.postId,
    required this.data,
  });

  final String postId;
  final Map<String, dynamic> data;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  static const Color _deleteRed = Color(0xFFE53935);
  bool _isPaymentLoading = false;

  static const List<int> _amountPresets = [10000, 30000, 50000, 100000];

  Future<void> _onDonateTap() async {
    final user = AuthRepository.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 후 후원할 수 있습니다.')),
      );
      return;
    }
    final title = widget.data[FirestorePostKeys.title]?.toString() ?? '(제목 없음)';
    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => _AmountSelectDialog(amountPresets: _amountPresets),
    );
    if (selected == null || selected <= 0 || !mounted) return;
    debugPrint('[WITHPAY] : 금액 선택됨 — $selected 원');

    final balance = await getWithPayBalance(user.id);
    if (!mounted) return;

    if (balance == 0) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('WITH Pay'),
          content: const Text('잔액이 없습니다. WITH Pay를 충전하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('충전하기'),
            ),
          ],
        ),
      );
      if (go == true && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => RechargeScreen(userId: user.id)),
        );
      }
      return;
    }

    if (balance < selected) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('잔액 부족'),
          content: const Text('잔액이 부족합니다. 충전 후 이용해주세요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('충전하기'),
            ),
          ],
        ),
      );
      if (go == true && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => RechargeScreen(userId: user.id)),
        );
      }
      return;
    }

    setState(() => _isPaymentLoading = true);
    final ok = await processPaymentWithWithPay(
      userId: user.id,
      postId: widget.postId,
      amount: selected,
      postTitle: title,
    );
    if (!mounted) return;
    setState(() => _isPaymentLoading = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('결제 성공 — 감사합니다.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('결제 처리에 실패했습니다. 다시 시도해 주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = AuthRepository.instance.currentUser?.type == UserType.admin ||
        AuthRepository.instance.currentUser?.isAdmin == true;
    debugPrint('[SYSTEM] : PostDetailScreen 빌드 — isAdmin=$isAdmin');
    final title = widget.data[FirestorePostKeys.title]?.toString() ?? '(제목 없음)';
    final content = widget.data[FirestorePostKeys.content]?.toString() ?? '';
    final patientName = widget.data[FirestorePostKeys.patientName]?.toString() ?? '-';
    final fundingType = widget.data[FirestorePostKeys.fundingType]?.toString() ?? FirestorePostKeys.fundingTypeMoney;
    final usagePurpose = (widget.data[FirestorePostKeys.usagePurpose]?.toString() ?? '').trim();
    final imageUrls = widget.data[FirestorePostKeys.imageUrls] is List
        ? (widget.data[FirestorePostKeys.imageUrls] as List).cast<String>()
        : <String>[];

    return Stack(
      children: [
        Scaffold(
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
                            if (usagePurpose.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.coral.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.coral.withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.savings_outlined, size: 20, color: AppColors.coral),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        fundingType == FirestorePostKeys.fundingTypeGoods
                                            ? '후원은 이렇게 사용됩니다: $usagePurpose'
                                            : '후원금은 이렇게 사용됩니다: $usagePurpose',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
                          onPressed: _isPaymentLoading ? null : _onDonateTap,
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
                            onPressed: _isPaymentLoading
                                ? null
                                : () async {
                                    debugPrint('[SYSTEM] : [ADMIN] 메인 상세에서 게시물 삭제 요청 — postId=${widget.postId}');
                                    final confirm = await showDeletePostConfirmDialog(context);
                                    if (!confirm) return;
                                    final ok = await deletePost(widget.postId);
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
        ),
        if (_isPaymentLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black38,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      '결제 진행 중...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 금액 선택 다이얼로그 — 프리셋 + 결제하기
class _AmountSelectDialog extends StatefulWidget {
  const _AmountSelectDialog({required this.amountPresets});

  final List<int> amountPresets;

  @override
  State<_AmountSelectDialog> createState() => _AmountSelectDialogState();
}

class _AmountSelectDialogState extends State<_AmountSelectDialog> {
  int? _selectedAmount;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('금액 선택'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...widget.amountPresets.map((amount) => RadioListTile<int>(
                  title: Text('${_formatAmount(amount)}원'),
                  value: amount,
                  groupValue: _selectedAmount,
                  onChanged: (v) => setState(() => _selectedAmount = v),
                )),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _selectedAmount == null
              ? null
              : () => Navigator.of(context).pop(_selectedAmount),
          child: const Text('결제하기'),
        ),
      ],
    );
  }

  String _formatAmount(int value) {
    if (value >= 10000) return '${value ~/ 10000}만';
    return value.toString();
  }
}
