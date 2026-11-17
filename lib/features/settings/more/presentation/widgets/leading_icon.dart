import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';

class LeadingIcon extends StatelessWidget {
  const LeadingIcon({
    super.key,
    required this.icon,
    this.danger = false,
    this.asset,
  });

  final IconData icon;
  final bool danger;

  /// 그림으로 보여 줄 SVG. 있으면 회색 네모 대신 이 그림을 쓴다(5차 465).
  /// 상품 줄(구독·광고 제거)만 색이 있어 눈에 들어오게 한다.
  final String? asset;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = danger
        ? context.tokens.danger.withValues(alpha: 0.08)
        : cs.onSurface.withValues(alpha: 0.06);
    final fg =
        danger ? context.tokens.danger : cs.onSurface.withValues(alpha: 0.75);

    if (asset != null) {
      return SizedBox(
        width: 36,
        height: 36,
        child: Center(
          child: SvgPicture.asset(asset!, width: 30, height: 30),
        ),
      );
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outlineVariant, width: 0.8),
      ),
      child: Icon(icon, size: 18, color: fg),
    );
  }
}
