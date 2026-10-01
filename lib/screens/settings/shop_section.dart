import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/iap/iap_service.dart';
import '../../state/auth_state.dart';
import '../../state/iap_state.dart';
import '../../widgets/app_card.dart';
import '../../widgets/section_header.dart';

/// 설정 화면의 "상점" 섹션 — 광고 제거(비소모성) 구매 + 구매 복원.
/// 힌트쿠폰 구매는 퀴즈 화면 힌트 영역에 있음(그 자리에서 바로 쓰이는 게 자연스러워서).
class ShopSection extends ConsumerWidget {
  const ShopSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final adsRemoved = ref.watch(adsRemovedProvider);
    final iap = ref.watch(iapProvider);

    ref.listen(iapProvider, (prev, next) {
      if (next.message != null && next.message != prev?.message) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.message!)));
      }
    });

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
                    : '배너·전면 광고를 영구히 없애요${_priceSuffix(iap, IapService.kRemoveAdsId)}'),
                trailing: adsRemoved
                    ? null
                    : SizedBox(
                        width: 72,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          onPressed: iap.busy
                              ? null
                              : () => _buyRemoveAds(context, ref),
                          child: iap.busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('구매'),
                        ),
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

  /// 실제 스토어 가격을 아직 못 받았으면(콘솔 상품 미등록 등) 괄호를 아예 안 붙인다
  /// — 확정 안 된 가격을 함부로 하드코딩해서 보여주지 않기 위함.
  String _priceSuffix(IapState iap, String productId) {
    final price = iap.products[productId]?.price;
    return price == null ? '' : ' ($price)';
  }

  bool _requireLogin(BuildContext context, WidgetRef ref) {
    if (ref.read(authProvider).loggedIn) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('구매는 로그인 후 이용할 수 있어요 — 위 계정 섹션에서 먼저 로그인해 주세요')),
    );
    return false;
  }

  void _buyRemoveAds(BuildContext context, WidgetRef ref) {
    if (!_requireLogin(context, ref)) return;
    ref.read(iapProvider.notifier).buy(IapService.kRemoveAdsId);
  }

  void _restore(BuildContext context, WidgetRef ref) {
    if (!_requireLogin(context, ref)) return;
    ref.read(iapProvider.notifier).restore();
  }
}
