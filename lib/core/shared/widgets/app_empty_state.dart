import 'package:flutter/material.dart';

import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';

/// 목록이 비었을 때 보여주는 안내.
///
/// 아이콘, 한 줄 제목, 설명, 그리고 할 일이 있으면 버튼 하나.
/// 전에는 화면마다 따로 만든 빈 화면 위젯이 다섯 벌 있었고, 그 밖에도
/// `Center(child: Text(...))` 한 줄짜리가 여기저기 흩어져 있었다.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    this.icon,
    this.description,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  /// 한 줄 제목. 무엇이 비었는지 말한다.
  final String title;

  /// 없으면 제목부터 그린다.
  final IconData? icon;

  /// 왜 비었는지, 어떻게 채우는지.
  final String? description;

  /// [onAction]과 함께 줄 때만 버튼이 나온다.
  final String? actionLabel;
  final VoidCallback? onAction;

  /// 목록 안에 끼워 넣을 때처럼 자리가 좁으면 true. 위아래 여백을 줄인다.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final showAction = actionLabel != null && onAction != null;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: compact ? AppSpacing.xl : AppSpacing.xxxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 48, color: tokens.textDisabled),
              const SizedBox(height: AppSpacing.md),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.texts.titleMedium.copyWith(
                fontWeight: FontWeight.w800,
                color: tokens.textPrimary,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: AppSpacing.xs + 2),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: context.texts.bodyMedium
                    .copyWith(color: tokens.textSecondary, height: 1.4),
              ),
            ],
            if (showAction) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
