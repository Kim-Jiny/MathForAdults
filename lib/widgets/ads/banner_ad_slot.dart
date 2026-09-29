import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../services/ads/ad_ids.dart';
import '../../state/iap_state.dart';

export '../../services/ads/ad_ids.dart' show BannerPlacement;

/// 표준 320×50 배너를 띄우는 재사용 위젯.
///
/// 광고가 로드되기 전·실패 시에는 빈 공간([SizedBox.shrink])을 반환해
/// 레이아웃을 차지하지 않는다. 스크롤 리스트 어디에나 끼워 넣을 수 있다.
/// [placement] 에 따라 화면별 광고 단위 ID를 사용한다.
/// "광고 제거"를 구매했으면([adsRemovedProvider]) 아예 로드하지 않는다.
class BannerAdSlot extends ConsumerStatefulWidget {
  /// 이 배너가 놓인 화면 위치 — 광고 단위 ID 결정.
  final BannerPlacement placement;

  /// 광고 위/아래 여백. 리스트에 끼울 때 카드들과 간격 확보용.
  final EdgeInsets margin;

  const BannerAdSlot({
    super.key,
    required this.placement,
    this.margin = const EdgeInsets.symmetric(vertical: 12),
  });

  @override
  ConsumerState<BannerAdSlot> createState() => _BannerAdSlotState();
}

class _BannerAdSlotState extends ConsumerState<BannerAdSlot> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (!ref.read(adsRemovedProvider)) _load();
  }

  void _load() {
    final ad = BannerAd(
      adUnitId: AdIds.banner(widget.placement),
      size: AdSize.banner, // 표준 320×50
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) => ad.dispose(),
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adsRemoved = ref.watch(adsRemovedProvider);
    // 로드돼 있던 중에 구매가 확정된 경우 리소스 정리(side effect라 listen에서 처리).
    ref.listen<bool>(adsRemovedProvider, (prev, next) {
      if (next && _ad != null) {
        setState(() {
          _ad!.dispose();
          _ad = null;
          _loaded = false;
        });
      }
    });
    if (adsRemoved) return const SizedBox.shrink();
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return Padding(
      padding: widget.margin,
      child: Center(
        child: SizedBox(
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          child: AdWidget(ad: ad),
        ),
      ),
    );
  }
}
