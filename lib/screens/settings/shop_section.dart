import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/iap/iap_service.dart';
import '../../state/auth_state.dart';
import '../../state/iap_state.dart';
import '../../widgets/app_card.dart';
import '../../widgets/iap/purchase_confirm_dialog.dart';
import '../../widgets/section_header.dart';

/// 설정 화면의 "상점" 섹션 — 광고 제거(비소모성) + 힌트쿠폰(소모성) 구매 + 구매 복원.
class ShopSection extends ConsumerWidget {
  const ShopSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final adsRemoved = ref.watch(adsRemovedProvider);
    final iap = ref.watch(iapProvider);
    final loggedIn = ref.watch(authProvider).loggedIn;
    final hintCoupons = iap.hintCoupons;

    ref.listen(iapProvider, (prev, next) {
      if (next.message != null && next.message != prev?.message) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.message!)));
      }
    });

    final removeAdsPrice = iapPriceOf(iap, IapService.kRemoveAdsId);
    final hintCouponsPrice = iapPriceOf(iap, IapService.kHintCoupons10Id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('상점'),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  adsRemoved ? Icons.check_circle_rounded : Icons.block_rounded,
                  color: adsRemoved ? Colors.green : scheme.primary,
                ),
                title: const Text('광고 제거',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(adsRemoved
                    ? '배너·전면 광고가 제거됐어요'
                    : removeAdsPrice == null
                        ? '배너·전면 광고를 영구히 없애요'
                        : '배너·전면 광고를 영구히 없애요 ($removeAdsPrice)'),
                trailing: adsRemoved
                    ? null
                    : _buyButton(
                        busy: iap.busy,
                        onPressed: () => _buyRemoveAds(context, ref),
                      ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: Icon(Icons.confirmation_number_rounded,
                    color: scheme.secondary),
                title: const Text('힌트쿠폰 10개',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(!loggedIn
                    ? '로그인 후 구매·사용할 수 있어요'
                    : hintCouponsPrice == null
                        ? '현재 남은 쿠폰 $hintCoupons개 · 10개 충전'
                        : '현재 남은 쿠폰 $hintCoupons개 · 10개 충전 ($hintCouponsPrice)'),
                trailing: _buyButton(
                  busy: iap.busy,
                  onPressed: () => _buyHintCoupons(context, ref),
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.restore_rounded),
                title: const Text('구매 복원',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('다른 기기에서 산 항목을 이 기기에도 반영해요'),
                onTap: iap.busy ? null : () => _restore(context, ref),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
      ],
    );
  }

  /// ListTile.trailing에 버튼을 바로 꽂으면 특정 레이아웃 패스에서
  /// "Trailing widget consumes the entire tile width" 어서션이 떠서 화면 전체가
  /// 렌더 실패한다 — SizedBox로 폭을 고정해둔다.
  Widget _buyButton({required bool busy, required VoidCallback onPressed}) {
    return SizedBox(
      width: 72,
      child: FilledButton(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        onPressed: busy ? null : onPressed,
        child: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('구매'),
      ),
    );
  }

  bool _requireLogin(BuildContext context, WidgetRef ref) {
    if (ref.read(authProvider).loggedIn) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('구매는 로그인 후 이용할 수 있어요 — 위 계정 섹션에서 먼저 로그인해 주세요')),
    );
    return false;
  }

  Future<void> _buyRemoveAds(BuildContext context, WidgetRef ref) async {
    if (!_requireLogin(context, ref)) return;
    final price = iapPriceOf(ref.read(iapProvider), IapService.kRemoveAdsId);
    final confirmed = await confirmPurchaseDialog(
      context,
      title: '광고 제거 구매',
      description: '배너·전면 광고를 영구히 없애요. 한 번 구매하면 계정 기준으로 다른 기기에도 적용돼요.',
      price: price,
    );
    if (!confirmed || !context.mounted) return;
    ref.read(iapProvider.notifier).buy(IapService.kRemoveAdsId);
  }

  Future<void> _buyHintCoupons(BuildContext context, WidgetRef ref) async {
    if (!_requireLogin(context, ref)) return;
    final price =
        iapPriceOf(ref.read(iapProvider), IapService.kHintCoupons10Id);
    final confirmed = await confirmPurchaseDialog(
      context,
      title: '힌트쿠폰 10개 구매',
      description: '힌트쿠폰 10개를 충전해요. 쿠폰이 있으면 광고 없이 바로 힌트를 볼 수 있어요.',
      price: price,
    );
    if (!confirmed || !context.mounted) return;
    ref.read(iapProvider.notifier).buy(IapService.kHintCoupons10Id);
  }

  void _restore(BuildContext context, WidgetRef ref) {
    if (!_requireLogin(context, ref)) return;
    ref.read(iapProvider.notifier).restore();
  }
}
