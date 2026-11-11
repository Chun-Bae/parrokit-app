import 'package:flutter/material.dart';
import 'package:parrokit/features/content-studio/shared/studio_colors.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/features/content-studio/tts/domain/models/tts_gemini_models.dart';
import 'package:parrokit/features/content-studio/tts/presentation/providers/tts_provider.dart';

class TtsGeminiVoiceSelectionSheet extends StatelessWidget {
  const TtsGeminiVoiceSelectionSheet({super.key, required this.provider});

  final TtsProvider provider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: context.tokens.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.tokens.disabled,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              'Gemini 보이스 에이전트 선택',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: geminiVoices.length,
              itemBuilder: (context, index) {
                final voice = geminiVoices[index];
                // Gemini의 경우 기본값이 비어있을 수 있으므로 빈 값이면 첫 번째를 선택한 것으로 간주
                final isSelected = provider.voiceId == voice.id ||
                    (provider.voiceId.isEmpty && index == 0);

                return ListTile(
                  title: Text(
                    voice.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? StudioColors.geminiPurple : null,
                    ),
                  ),
                  subtitle: Text(
                    voice.description,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: context.tokens.textSecondary,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle_rounded,
                          color: StudioColors.geminiPurple)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  onTap: () {
                    provider.updateVoiceId(voice.id);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
