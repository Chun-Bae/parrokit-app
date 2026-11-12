// 더보기의 지갑 카드. 패롯·크래커 잔액과 광고 보상·환전 버튼을 한 카드에 둔다.
//
// 전에는 계정 카드의 잔액 배지, "패롯 받기" 섹션(설명 두 줄 + 버튼),
// "환전소" 섹션(설명 한 줄 + 버튼)이 따로 있었다. 하는 일은 같고 글만 줄였다.
// 두 재화 설명은 ? 버튼 하나로 모았다.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/shared/theme/app_colors.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import '../exchange_screen.dart';
import 'ad_reward_button.dart';

final _count = NumberFormat.decimalPattern('ko');

class WalletSection extends StatelessWidget {
  const WalletSection({super.key});

  void _showCurrencyInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('패롯과 크래커'),
        content: const Text(
          '패롯은 자막·음성·영상을 만들 때 써요. 광고를 보거나 충전해서 받아요.\n\n'
          '크래커는 커뮤니티에서 써요. 질문에 보상으로 걸고, 내 답변이 채택되면 받아요.\n\n'
          '1 패롯은 1,000 크래커로 바꿀 수 있어요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final user = context.watch<UserProvider>().currentUser;

    final buttonStyle = FilledButton.styleFrom(
      backgroundColor: cs.surface,
      foregroundColor: cs.onSurface,
      disabledBackgroundColor: cs.surface.withValues(alpha: 0.6),
      disabledForegroundColor: cs.onSurfaceVariant,
      elevation: 0,
      minimumSize: const Size.fromHeight(44),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      textStyle: context.texts.labelLarge.copyWith(fontWeight: FontWeight.w700),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
      decoration: BoxDecoration(
        color: tokens.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _Balance(
                  icon: Icons.auto_awesome_rounded,
                  color: AppColors.parrotCurrency,
                  label: '패롯',
                  value: _count.format(user?.parrots ?? 0),
                ),
              ),
              Expanded(
                child: _Balance(
                  icon: Icons.cookie_rounded,
                  color: AppColors.crackerCurrency,
                  label: '크래커',
                  value: _count.format(user?.crackers ?? 0),
                ),
              ),
              IconButton(
                tooltip: '패롯과 크래커',
                onPressed: () => _showCurrencyInfo(context),
                icon: Icon(Icons.help_outline_rounded,
                    size: 20, color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Expanded(child: AdRewardButton(style: buttonStyle)),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    style: buttonStyle,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ExchangeScreen()),
                    ),
                    icon: const Icon(Icons.currency_exchange_rounded, size: 18),
                    label: const Text('환전'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Balance extends StatelessWidget {
  const _Balance({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: context.texts.labelMedium
                    .copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: context.texts.headlineSmall
                .copyWith(fontWeight: FontWeight.w800, color: cs.onSurface),
          ),
        ),
      ],
    );
  }
}
