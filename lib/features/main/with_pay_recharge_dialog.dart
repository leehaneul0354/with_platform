// 목적: WITH Pay 충전 UI — 금액 선택(1만/3만/5만/10만) → 결제 수단 선택 → 가상 결제 → 성공 화면.
// 흐름: 마이페이지 카드 탭 또는 후원 화면 '충전 유도' 시 다이얼로그/페이지로 노출.

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/payment_service.dart';
import 'with_pay_payment_flow.dart';

const List<int> _kRechargePresets = [10000, 30000, 50000, 100000];

/// 다이얼로그로 충전하기 (마이페이지용)
Future<void> showWithPayRechargeDialog(BuildContext context, String userId) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => _WithPayRechargeContent(
      userId: userId,
      onSuccess: () => Navigator.of(ctx).pop(),
    ),
  );
}

/// 충전 콘텐츠 — 금액 선택 + [충전하기] → 결제 수단 BottomSheet → startPay(모의) → SuccessScreen
class _WithPayRechargeContent extends StatefulWidget {
  const _WithPayRechargeContent({
    required this.userId,
    required this.onSuccess,
  });

  final String userId;
  final VoidCallback onSuccess;

  @override
  State<_WithPayRechargeContent> createState() => _WithPayRechargeContentState();
}

class _WithPayRechargeContentState extends State<_WithPayRechargeContent> {
  int? _selectedAmount;
  bool _loading = false;

  Future<void> _onRecharge() async {
    final amount = _selectedAmount;
    if (amount == null || amount <= 0) return;
    setState(() => _loading = true);

    final method = await showPaymentMethodSheet(context, amount);
    if (!mounted) {
      setState(() => _loading = false);
      return;
    }
    if (method == null) {
      setState(() => _loading = false);
      return;
    }

    final newBalance = await startPay(
      context,
      userId: widget.userId,
      amount: amount,
      method: method,
    );
    if (!mounted) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = false);

    if (newBalance != null) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => RechargeSuccessScreen(newBalance: newBalance),
        ),
      );
      if (!mounted) return;
      widget.onSuccess();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('WITH Pay 충전'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '충전할 금액을 선택하세요.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ..._kRechargePresets.map((amount) => RadioListTile<int>(
                  title: Text('${_formatAmount(amount)}원'),
                  value: amount,
                  groupValue: _selectedAmount,
                  onChanged: _loading ? null : (v) => setState(() => _selectedAmount = v),
                )),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _loading || _selectedAmount == null
              ? null
              : _onRecharge,
          style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('충전'),
        ),
      ],
    );
  }

  static String _formatAmount(int value) {
    if (value >= 10000) return '${value ~/ 10000}만';
    return value.toString();
  }
}

/// 충전 전용 페이지. 열리면 충전 다이얼로그를 띄우고, 다이얼로그 닫기 시 본 페이지도 pop.
/// 후원 화면에서 '충전하시겠습니까?' 확인 시 이 페이지로 이동할 때 사용.
class RechargeScreen extends StatefulWidget {
  const RechargeScreen({super.key, required this.userId});
  final String userId;

  @override
  State<RechargeScreen> createState() => _RechargeScreenState();
}

class _RechargeScreenState extends State<RechargeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openDialog());
  }

  Future<void> _openDialog() async {
    await showWithPayRechargeDialog(context, widget.userId);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WITH Pay 충전'),
        backgroundColor: AppColors.yellow,
        foregroundColor: AppColors.textPrimary,
      ),
      body: const Center(
        child: Text('충전할 금액을 선택해 주세요.', style: TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }
}
