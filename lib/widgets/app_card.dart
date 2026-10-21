import 'package:flutter/material.dart';

/// 앱 전역에서 쓰는 카드. 말랑한 테두리 + 아래쪽 "도톰한 입술" 그림자(블러 없는 단색)로
/// 스티커 같은 귀여운 느낌을 낸다. 과하지 않게 테두리색과 같은 톤만 쓴다.
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(18),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(24);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(color: scheme.outlineVariant, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: color == null
            ? scheme.surface
            : Color.alphaBlend(color!, scheme.surface),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: scheme.outlineVariant, width: 2),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
