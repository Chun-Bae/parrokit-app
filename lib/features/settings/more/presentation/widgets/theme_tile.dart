import 'package:flutter/material.dart';

import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/widgets/app_segmented_tabs.dart';
import 'leading_icon.dart';

/// 설정의 테마 고르기 줄.
///
/// 셋 중 하나를 고르는 것이라 앱 전역 세그먼트 컨트롤([AppSegmentedTabs])을 쓴다.
class ThemeTile extends StatelessWidget {
  const ThemeTile({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  static const _modes = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];
  static const _labels = ['시스템', '라이트', '다크'];

  /// 세 칸이 안 좁아 보이도록 오른쪽에 떼어 두는 너비.
  static const double _controlWidth = 240;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const LeadingIcon(icon: Icons.dark_mode_outlined),
        const SizedBox(width: AppSpacing.sm + 2),
        Expanded(
          child: Text(
            '테마',
            style:
                context.texts.bodyLarge.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        SizedBox(
          width: _controlWidth,
          child: AppSegmentedTabs(
            selectedIndex: _modes.indexOf(value),
            onChanged: (index) => onChanged(_modes[index]),
            segments: [
              for (final label in _labels) AppSegment(label: label),
            ],
          ),
        ),
      ],
    );
  }
}
