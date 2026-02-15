// 목적: 결제 진입점 추상화. 가상 결제(모의) 후 추후 Portone 등 실제 PG 연동 시 startPay 구현만 교체.
// 흐름: 충전 금액·수단 선택 후 startPay 호출 → 모의/실제 결제 → 성공 시 잔액 반환.

import 'package:flutter/material.dart';
import 'payment_method.dart';
import '../../features/main/with_pay_payment_flow.dart';

/// 결제 시작. 현재는 가상 결제(풀스크린 모달) 후 잔액 반환.
/// 추후: Portone 등 PG 연동 시 이 함수 내부만 교체.
/// [context] 결제 UI를 띄울 컨텍스트.
/// 반환: 성공 시 충전 후 잔액, 취소/실패 시 null.
Future<int?> startPay(
  BuildContext context, {
  required String userId,
  required int amount,
  required PaymentMethod method,
}) async {
  if (amount <= 0) return null;
  final result = await Navigator.of(context).push<int>(
    MaterialPageRoute<int>(
      fullscreenDialog: true,
      builder: (_) => PaymentWebViewMock(
        userId: userId,
        amount: amount,
        paymentMethod: method,
      ),
    ),
  );
  return result;
}
