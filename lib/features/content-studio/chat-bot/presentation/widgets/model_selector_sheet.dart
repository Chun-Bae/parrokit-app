import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import '../chat_bot_provider.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/widgets/app_bottom_sheet.dart';

/// 아직 고를 수 없는 모델의 까닭. 카드 안에 적는다(5차 370).
const String chatbotProLockedReason = '출시 후 이용할 수 있어요.';

void showModelSelectorBottomSheet(
    BuildContext context, ChatBotProvider provider) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final bg = isDark ? context.tokens.surfaceContainer : context.tokens.surface;

  showAppSheet(
    context: context,
    builder: (context) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xxl),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI 모델 고르기',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '하려는 일에 맞는 Gemini AI 모델을 골라 주세요.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark
                    ? context.tokens.textTertiary
                    : context.tokens.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            // 모델 1: Flash-Lite. 서버는 이 모델만 쓴다(Gemini 2.5는 Vertex에서
            // 2026-10 종료, 5차). 내부 값 'gemini-2.5-flash'는 선택 표시용으로만 남는다.
            ModelOptionCard(
              title: 'Gemini 3.1 Flash-Lite',
              description: '가볍고 빨라요. 간단한 아이디어를 떠올리거나 빨리 만들어 볼 때 좋아요.',
              speedText: '매우 빠름',
              costText: '가장 저렴함',
              isSelected: provider.selectedModel == 'gemini-2.5-flash',
              accentColor: context.tokens.primary,
              onTap: () {
                provider.updateSelectedModel('gemini-2.5-flash');
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 12),

            // 모델 2: Pro (유료 플랜 전용, 현재는 잠금)
            ModelOptionCard(
              title: 'Gemini Pro',
              description: '긴 글을 잘 따라가요. 장면을 짜거나 대사를 꼼꼼히 다듬을 때 좋아요.',
              speedText: '보통',
              costText: '보통',
              isSelected: provider.selectedModel == 'gemini-2.5-pro',
              accentColor: context.tokens.secondary,
              locked: true,
              // 눌렀을 때 토스트로 알렸는데, 이 화면은 바텀시트라 시트가
              // 아래를 덮어 보이지 않았다(5차 369). 카드에 적어 둔다.
              lockedReason: chatbotProLockedReason,
              onTap: null,
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
    this.lockedReason,
  });

  final String title;
  final String description;
  final String speedText;
  final String costText;
  final bool isSelected;
  final Color accentColor;

  /// 고를 수 없는 모델이면 null.
  final VoidCallback? onTap;

  /// 유료 플랜 전용 등 아직 이용할 수 없는 모델인지 여부.
  final bool locked;

  /// 고를 수 없는 까닭. 카드 안에 적는다(5차 370).
  final String? lockedReason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark
        ? (isSelected
            ? accentColor.withValues(alpha: 0.1)
            : context.tokens.surfaceContainerHigh)
        : (isSelected
            ? accentColor.withValues(alpha: 0.05)
            : context.tokens.surfaceContainerHigh);

    final borderColor =
        isSelected ? accentColor : (context.tokens.dividerSubtle);

    return Opacity(
      opacity: locked ? 0.5 : 1.0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(AppRadius.lg),
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
                                ? (isDark
                                    ? context.tokens.textPrimary
                                    : accentColor)
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
                        color: context.tokens.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    if (locked && lockedReason != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        lockedReason!,
                        key: const ValueKey('model-locked-reason'),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.error),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              locked
                  ? Icon(
                      Icons.lock_rounded,
                      size: 20,
                      color: context.tokens.textDisabled,
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
                              : (context.tokens.textDisabled),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        label,
        style: context.texts.labelSmall.copyWith(
          color: context.tokens.textSecondary,
        ),
      ),
    );
  }
}
