import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/features/content-studio/tts/domain/models/tts_elevenlabs_models.dart';
import 'package:parrokit/features/content-studio/tts/presentation/providers/tts_provider.dart';

class TtsElevenLabsModelSelectionSheet extends StatelessWidget {
  const TtsElevenLabsModelSelectionSheet({super.key, required this.provider});

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
                borderRadius: BorderRadius.circular(AppRadius.track),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              'ElevenLabs 음성 생성 모델 선택',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemCount: elevenLabsModels.length,
              itemBuilder: (context, index) {
                final model = elevenLabsModels[index];
                final isSelected = provider.modelId == model.id ||
                    (provider.modelId == null &&
                        model.id == 'eleven_multilingual_v2');

                return ListTile(
                  title: Text(
                    model.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? context.tokens.secondary : null,
                    ),
                  ),
                  subtitle: Text(
                    model.description,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: context.tokens.textSecondary,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle_rounded,
                          color: context.tokens.secondary)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  onTap: () {
                    provider.updateModelId(model.id);
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
