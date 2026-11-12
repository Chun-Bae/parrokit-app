import 'package:flutter/material.dart';
import 'package:parrokit/features/settings/more/presentation/exchange_screen.dart';

/// 환전소 섹션
/// 더보기 화면에서 패롯 <-> 크래커 환전 화면으로 진입하는 버튼
class ExchangeSection extends StatelessWidget {
  const ExchangeSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '환전소',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          '패롯과 크래커를 상호 교환해 보세요. 1 패롯은 1,000 크래커와 같습니다.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ExchangeScreen()),
              );
            },
            icon: const Icon(Icons.currency_exchange_rounded, size: 18),
            label: const Text('환전소 바로가기'),
          ),
        ),
      ],
    );
  }
}
