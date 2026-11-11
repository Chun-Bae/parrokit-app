import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/theme/app_colors.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/features/content-studio/tts/domain/repositories/tts_generation_repository.dart';

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
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
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
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
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
