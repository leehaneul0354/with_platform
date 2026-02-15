// 목적: WITH Pay 결제 UX — 결제 수단 선택 시트, 가상 결제 모달, 충전 완료 성공 화면.
// 흐름: 금액 선택 → [충전하기] → 결제 수단 BottomSheet → PaymentWebViewMock → 확인 → SuccessScreen.

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/payment_method.dart';
import '../../core/services/with_pay_service.dart';

/// 충전 금액 선택 후 [충전하기] 탭 시 하단에서 올라오는 결제 수단 선택 시트
Future<PaymentMethod?> showPaymentMethodSheet(BuildContext context, int amount) async {
  return showModalBottomSheet<PaymentMethod>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '결제 수단 선택',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_formatAmount(amount)}원',
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            _PaymentMethodTile(
              icon: Icons.credit_card,
              iconBg: Colors.indigo.shade100,
              label: PaymentMethod.card.label,
              method: PaymentMethod.card,
              onTap: () => Navigator.of(ctx).pop(PaymentMethod.card),
            ),
            _PaymentMethodTile(
              icon: Icons.chat_bubble_outline,
              iconBg: const Color(0xFFFEE500),
              label: PaymentMethod.kakao.label,
              method: PaymentMethod.kakao,
              onTap: () => Navigator.of(ctx).pop(PaymentMethod.kakao),
            ),
            _PaymentMethodTile(
              icon: Icons.verified_user_outlined,
              iconBg: const Color(0xFF03C75A),
              label: PaymentMethod.naver.label,
              method: PaymentMethod.naver,
              onTap: () => Navigator.of(ctx).pop(PaymentMethod.naver),
            ),
            _PaymentMethodTile(
              icon: Icons.bolt,
              iconBg: const Color(0xFF0064FF),
              label: PaymentMethod.toss.label,
              method: PaymentMethod.toss,
              onTap: () => Navigator.of(ctx).pop(PaymentMethod.toss),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.icon,
    required this.iconBg,
    required this.label,
    required this.method,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final String label;
  final PaymentMethod method;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 24),
      ),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: onTap,
    );
  }
}

String _formatAmount(int value) {
  if (value >= 10000) return '${value ~/ 10000}만';
  return value.toString();
}

/// 가상 결제 브라우저 시뮬레이션 — 풀스크린 모달.
/// 중앙: 결제 수단 로고 + "안전한 결제를 위해 보안 페이지로 이동 중입니다..." + 인디케이터
/// 2.5초 후: "지문 인식 또는 비밀번호를 입력해주세요" + [확인] 버튼 → rechargeWithPay 후 pop(잔액)
class PaymentWebViewMock extends StatefulWidget {
  const PaymentWebViewMock({
    super.key,
    required this.userId,
    required this.amount,
    required this.paymentMethod,
  });

  final String userId;
  final int amount;
  final PaymentMethod paymentMethod;

  @override
  State<PaymentWebViewMock> createState() => _PaymentWebViewMockState();
}

class _PaymentWebViewMockState extends State<PaymentWebViewMock> {
  bool _showConfirm = false;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _showConfirm = true);
    });
  }

  Future<void> _onConfirm() async {
    if (_processing) return;
    setState(() => _processing = true);
    final newBalance = await rechargeWithPay(
      widget.userId,
      widget.amount,
      paymentMethod: widget.paymentMethod.id,
    );
    if (!mounted) return;
    setState(() => _processing = false);
    if (newBalance != null) {
      Navigator.of(context).pop(newBalance);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('결제 처리에 실패했습니다. 다시 시도해 주세요.')),
      );
    }
  }

  Widget _buildLogo() {
    final icon = switch (widget.paymentMethod) {
      PaymentMethod.card => Icons.credit_card,
      PaymentMethod.kakao => Icons.chat_bubble_outline,
      PaymentMethod.naver => Icons.verified_user_outlined,
      PaymentMethod.toss => Icons.bolt,
    };
    final color = switch (widget.paymentMethod) {
      PaymentMethod.card => Colors.indigo,
      PaymentMethod.kakao => const Color(0xFF3C1E1E),
      PaymentMethod.naver => const Color(0xFF03C75A),
      PaymentMethod.toss => const Color(0xFF0064FF),
    };
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 40, color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          '${widget.paymentMethod.label} 결제',
          style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: _showConfirm ? _buildConfirmPhase() : _buildLoadingPhase(),
      ),
    );
  }

  Widget _buildLoadingPhase() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLogo(),
            const SizedBox(height: 24),
            Text(
              '안전한 결제를 위해 보안 페이지로 이동 중입니다...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmPhase() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLogo(),
            const SizedBox(height: 24),
            Text(
              '지문 인식 또는 비밀번호를 입력해주세요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _processing ? null : _onConfirm,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.coral,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _processing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('확인', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 충전 완료 성공 화면 — 초록 체크 + 문구 + 잔액 + [확인] → 마이페이지로 복귀 시 잔액 최신화
class RechargeSuccessScreen extends StatelessWidget {
  const RechargeSuccessScreen({super.key, required this.newBalance});

  final int newBalance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF4CAF50),
                  size: 64,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                '충전이 완료되었습니다!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '현재 잔액  ${_formatAmount(newBalance)}원',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.coral,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(newBalance),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.coral,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('확인', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

