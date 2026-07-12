import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_colors.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import '../chat_bot_provider.dart';

void showModelSelectorBottomSheet(
    BuildContext context, ChatBotProvider provider) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final bg = isDark ? AppColors.surfaceContainerDark : AppColors.surface;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    showDragHandle: false,
    builder: (context) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI 모델 선택',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '작업 성격에 맞는 Gemini AI 모델을 선택하세요.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            // 모델 1: Gemini 2.5 Flash
            ModelOptionCard(
              title: 'Gemini 2.5 Flash',
              description: '빠르고 경량화된 모델로 간단한 아이디어 구상과 신속한 생성 요청에 이상적입니다.',
              speedText: '매우 빠름',
              costText: '가장 저렴함',
              isSelected: provider.selectedModel == 'gemini-2.5-flash',
              accentColor: AppColors.primary,
              onTap: () {
                provider.updateSelectedModel('gemini-2.5-flash');
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 12),

            // 모델 2: Gemini 2.5 Pro (유료 플랜 전용, 현재는 잠금)
            ModelOptionCard(
              title: 'Gemini 2.5 Pro',
              description:
                  '정교한 논리 추론과 긴 문맥 파악에 특화되어 복잡한 씬 연출 및 고품질 대사 다듬기에 적합합니다.',
              speedText: '보통',
              costText: '보통',
              isSelected: provider.selectedModel == 'gemini-2.5-pro',
              accentColor: AppColors.secondary,
              locked: true,
              onTap: () {
                showToast('Gemini 2.5 Pro는 유료 플랜 전용이에요. 출시 후 이용할 수 있어요.');
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    },
  );
}

class ModelOptionCard extends StatelessWidget {
  const ModelOptionCard({
    super.key,
    required this.title,
    required this.description,
    required this.speedText,
    required this.costText,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
    this.locked = false,
  });

  final String title;
  final String description;
  final String speedText;
  final String costText;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  /// 유료 플랜 전용 등 아직 이용할 수 없는 모델인지 여부.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark
        ? (isSelected
            ? accentColor.withValues(alpha: 0.1)
            : AppColors.surfaceContainerHighDark)
        : (isSelected
            ? accentColor.withValues(alpha: 0.05)
            : AppColors.surfaceContainerHigh);

    final borderColor = isSelected
        ? accentColor
        : (isDark ? AppColors.dividerSubtleDark : AppColors.dividerSubtle);

    return Opacity(
      opacity: locked ? 0.5 : 1.0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor,
              width: isSelected ? 2.0 : 1.0,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: isSelected
                                ? (isDark ? Colors.white : accentColor)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 특성 칩
                        if (locked)
                          FeatureChip(label: '유료 플랜 전용', isDark: isDark)
                        else ...[
                          FeatureChip(label: speedText, isDark: isDark),
                          const SizedBox(width: 4),
                          FeatureChip(label: costText, isDark: isDark),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              locked
                  ? Icon(
                      Icons.lock_rounded,
                      size: 20,
                      color: isDark
                          ? AppColors.textDisabledDark
                          : AppColors.textDisabled,
                    )
                  : Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? accentColor : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? accentColor
                              : (isDark
                                  ? AppColors.textDisabledDark
                                  : AppColors.textDisabled),
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 12,
                            )
                          : null,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class FeatureChip extends StatelessWidget {
  const FeatureChip({
    super.key,
    required this.label,
    required this.isDark,
  });

  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
        ),
      ),
    );
  }
}
