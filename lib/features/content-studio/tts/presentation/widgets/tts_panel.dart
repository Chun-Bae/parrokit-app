import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';

/// 음성 만들기 화면의 한 묶음.
///
/// 전에는 묶음마다 테두리 있는 카드였다(5차 411, 사용자 요청: "카드형
/// 디자인부터 버리자"). 카드가 넷이라 화면이 상자로 가득 찼고, 안에 또
/// 회색 상자(옵션 줄)가 들어가 상자 속 상자가 됐다. 이제 제목 한 줄과
/// 내용만 두고, 묶음은 사이 여백으로 가른다.
class TtsPanel extends StatelessWidget {
  const TtsPanel({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: context.tokens.textSecondary,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}
