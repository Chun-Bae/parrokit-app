import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/theme/app_colors.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/features/content-studio/tts/domain/repositories/tts_generation_repository.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';

/// TTS 공급자 고르기.
///
/// 생김새는 [AppSegmentedTabs]와 같은 계열이지만 따로 만들어 둔다.
/// 고른 공급자마다 글자색이 다르고(Google은 primary, ElevenLabs는 secondary,
/// Gemini는 그라디언트) 그게 어느 엔진인지 알려 주는 표시 역할을 하기 때문이다.
/// 공용 위젯으로 옮기면 그 뜻이 사라진다.
class TtsProviderSelector extends StatelessWidget {
  const TtsProviderSelector({
    super.key,
    required this.selectedType,
    required this.onTypeChanged,
  });

  final TtsProviderType selectedType;
  final ValueChanged<TtsProviderType> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = context.tokens.surfaceContainerHigh;

    return Container(
      height: 48,
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth / 3;
          int selectedIndex = 0;
          if (selectedType == TtsProviderType.elevenlabs) {
            selectedIndex = 1;
          } else if (selectedType == TtsProviderType.gemini) {
            selectedIndex = 2;
          }

          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOutCubic,
                left: selectedIndex * width,
                width: width,
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? context.tokens.surfaceContainer
                        : context.tokens.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTypeChanged(TtsProviderType.google),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: theme.textTheme.bodyMedium!.copyWith(
                            fontWeight: FontWeight.w800,
                            color: selectedType == TtsProviderType.google
                                ? theme.colorScheme.primary
                                : (context.tokens.textSecondary),
                          ),
                          child: const Text('Google Cloud'),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTypeChanged(TtsProviderType.elevenlabs),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: theme.textTheme.bodyMedium!.copyWith(
                            fontWeight: FontWeight.w800,
                            color: selectedType == TtsProviderType.elevenlabs
                                ? context.tokens.secondary
                                : (context.tokens.textSecondary),
                          ),
                          child: const Text('ElevenLabs'),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTypeChanged(TtsProviderType.gemini),
                      child: Center(
                        child: selectedType == TtsProviderType.gemini
                            ? ShaderMask(
                                shaderCallback: (bounds) => AppColors
                                    .geminiGradient
                                    .createShader(bounds),
                                blendMode: BlendMode.srcIn,
                                child: Text(
                                  'Gemini',
                                  style: theme.textTheme.bodyMedium!.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color:
                                        Colors.white, // Required for ShaderMask
                                  ),
                                ),
                              )
                            : AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: theme.textTheme.bodyMedium!.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: context.tokens.textSecondary,
                                ),
                                child: const Text('Gemini'),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
