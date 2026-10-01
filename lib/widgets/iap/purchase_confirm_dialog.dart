import 'package:flutter/material.dart';

/// 구매 버튼을 누르자마자 바로 스토어 결제창으로 넘기지 않고, 뭘 얼마에 사는지
/// 먼저 보여주고 확인받는다. 취소하면 `buy()` 자체를 호출하지 않는다.
Future<bool> confirmPurchaseDialog(
  BuildContext context, {
  required String title,
  required String description,
  String? price,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(
        price == null ? description : '$description\n\n가격: $price',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('구매하기'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
