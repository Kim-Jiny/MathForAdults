import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const _refundPolicyUrl = 'https://duo.jiny.shop/mfa/refund';

/// 구매 버튼을 누르자마자 바로 스토어 결제창으로 넘기지 않고, 뭘 얼마에 사는지
/// 먼저 보여주고 확인받는다. 취소하면 `buy()` 자체를 호출하지 않는다.
///
/// [consumable]이 true(힌트쿠폰 등 소모성 상품)면 "사용하면 청약철회가 제한될 수
/// 있다"는 문구를 보여준다 — 전자상거래법상 디지털 콘텐츠 청약철회 제한 예외는
/// 구매 "전"에 이걸 고지해야 성립하므로, 설정 화면 환불 안내 페이지에만 있는 걸로는
/// 부족하고 결제 직전 이 시점에 보여줘야 한다.
Future<bool> confirmPurchaseDialog(
  BuildContext context, {
  required String title,
  required String description,
  String? price,
  bool consumable = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(price == null ? description : '$description\n\n가격: $price'),
          const SizedBox(height: 12),
          Text(
            consumable
                ? '결제 즉시 제공되는 디지털 상품이에요. 일부라도 사용하면 청약철회(환불)가 제한될 수 있어요.'
                : '결제 즉시 제공되는 디지털 상품이에요.',
            style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                  color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => _openRefundPolicy(dialogContext),
              child: const Text(
                '환불 안내 보기',
                style: TextStyle(fontSize: 13, decoration: TextDecoration.underline),
              ),
            ),
          ),
        ],
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

Future<void> _openRefundPolicy(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final ok = await launchUrl(Uri.parse(_refundPolicyUrl),
        mode: LaunchMode.externalApplication);
    if (!ok) throw Exception('open failed');
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('페이지를 열 수 없어요')));
  }
}
