import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';

Future<void> showVideoPromptRecommendationSheet(
  BuildContext context, {
  required List<Map<String, String>> recommendations,
  void Function(int tabIndex, Map<String, dynamic>? actionData)?
      onTriggerAction,
}) async {
  if (recommendations.isEmpty) return;

  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  int selectedIndex = 0;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.tokens.surfaceContainerHigh,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext sheetContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          final selectedPair = recommendations[selectedIndex];
          return SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.movie_filter_rounded,
                      size: 48,
                      color: context.tokens.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '추천 스크립트와 장면이 한 쌍으로 나왔어요',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '마음에 드는 세트를 고르면 스크립트와 영상 프롬프트가 함께 들어갑니다.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: context.tokens.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: recommendations.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final pair = recommendations[index];
                        final isSelected = selectedIndex == index;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              selectedIndex = index;
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? context.tokens.primary
                                    : (context.tokens.dividerSubtle),
                                width: isSelected ? 2 : 1,
                              ),
                              color: isSelected
                                  ? context.tokens.primary
                                      .withValues(alpha: 0.1)
                                  : (isDark
                                      ? context.tokens.surfaceContainer
                                      : context.tokens.surface),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isSelected
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_unchecked,
                                      color: isSelected
                                          ? context.tokens.primary
                                          : (context.tokens.textTertiary),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        '추천 세트 ${index + 1}',
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: context.tokens.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '스크립트',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: context.tokens.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  pair['script'] ?? '',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: context.tokens.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '장면 프롬프트',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: context.tokens.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  pair['prompt'] ?? '',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: context.tokens.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            child: const Text('닫기'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              Navigator.of(sheetContext).pop();
                              Navigator.of(context).pop();
                              if (onTriggerAction != null) {
                                onTriggerAction(2, {
                                  'script': selectedPair['script'] ?? '',
                                  'prompt': selectedPair['prompt'] ?? '',
                                });
                              }
                            },
                            child: const Text('한 쌍 넣기'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
