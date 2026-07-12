import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_colors.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/features/content-studio/tts/data/data_sources/tts_remote_data_source.dart';
import 'package:parrokit/features/content-studio/tts/data/repositories/tts_voice_cache.dart';
import 'package:parrokit/features/content-studio/tts/domain/models/tts_elevenlabs_models.dart';
import 'package:parrokit/features/content-studio/tts/presentation/providers/tts_provider.dart';

/// 국기 이모지(있으면) + 억양/언어 라벨을 한 줄로 조합합니다.
String _originTagText(String? flag, String label) {
  return flag != null ? '$flag $label 억양' : '$label 억양';
}

class TtsElevenLabsVoiceSelectionSheet extends StatefulWidget {
  const TtsElevenLabsVoiceSelectionSheet({
    super.key,
    required this.provider,
  });

  final TtsProvider provider;

  @override
  State<TtsElevenLabsVoiceSelectionSheet> createState() =>
      _TtsElevenLabsVoiceSelectionSheetState();
}

class _TtsElevenLabsVoiceSelectionSheetState
    extends State<TtsElevenLabsVoiceSelectionSheet> {
  /// null이면 전체보기.
  String? _selectedAccent;

  TtsProvider get provider => widget.provider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
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
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              'ElevenLabs 보이스 선택',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: _AccentNoticeBanner(isDark: isDark),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: FutureBuilder<List<TtsElevenLabsVoice>>(
              future: TtsVoiceCache()
                  .fetchElevenLabsVoicesIfNeeded(TtsRemoteDataSource()),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      '보이스 목록을 불러오지 못했습니다.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  );
                }

                final voices = snapshot.data ?? [];
                if (voices.isEmpty) {
                  return const Center(child: Text('사용 가능한 보이스가 없습니다.'));
                }

                final originFlagByLabel = <String, String?>{
                  for (final v in voices)
                    if (v.originLabel != null) v.originLabel!: v.originFlag,
                };
                final originOptions = originFlagByLabel.keys.toList()..sort();

                final filteredVoices = _selectedAccent == null
                    ? voices
                    : voices
                        .where((v) => v.originLabel == _selectedAccent)
                        .toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: _AccentFilterDropdown(
                        isDark: isDark,
                        selectedAccent: _selectedAccent,
                        options: originOptions,
                        flagByLabel: originFlagByLabel,
                        onChanged: (value) =>
                            setState(() => _selectedAccent = value),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Expanded(
                      child: filteredVoices.isEmpty
                          ? Center(
                              child: Text(
                                '해당 억양의 보이스가 없습니다.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondary,
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md),
                              itemCount: filteredVoices.length,
                              itemBuilder: (context, index) {
                                final voice = filteredVoices[index];
                                // 첫 로드 시 voiceId가 빈 값이면 첫 번째를 선택된 것으로 간주
                                final isSelected = provider.voiceId ==
                                        voice.id ||
                                    (provider.voiceId.isEmpty && index == 0);

                                return ListTile(
                                  title: Text(
                                    voice.name,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? const Color(0xFF9B72CB)
                                          : null,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        voice.friendlyDescription,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: isDark
                                              ? AppColors.textSecondaryDark
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                      if (voice.originLabel != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          _originTagText(voice.originFlag,
                                              voice.originLabel!),
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                            color: isDark
                                                ? AppColors.textSecondaryDark
                                                : AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  trailing: isSelected
                                      ? const Icon(Icons.check_circle_rounded,
                                          color: Color(0xFF9B72CB))
                                      : null,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.sm),
                                  ),
                                  onTap: () {
                                    provider.updateVoiceId(voice.id);
                                    Navigator.pop(context);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
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

class _AccentNoticeBanner extends StatelessWidget {
  const _AccentNoticeBanner({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.warningSoftDark : AppColors.warningSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isDark ? AppColors.warningDark : AppColors.warning,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: isDark ? AppColors.warningDark : AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '억양이 표시된 보이스는 다른 언어로 생성해도 그 억양이 남을 수 있어요. '
              '다만 실제로는 큰 차이가 느껴지지 않는 경우도 많으니 참고만 해주세요. '
              '학습 언어의 정확한 발음이 중요하면 Gemini 사용을 권장해요.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccentFilterDropdown extends StatelessWidget {
  const _AccentFilterDropdown({
    required this.isDark,
    required this.selectedAccent,
    required this.options,
    required this.flagByLabel,
    required this.onChanged,
  });

  final bool isDark;
  final String? selectedAccent;
  final List<String> options;
  final Map<String, String?> flagByLabel;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceContainerHighDark
            : AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: selectedAccent,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('전체보기'),
            ),
            ...options.map(
              (origin) => DropdownMenuItem<String?>(
                value: origin,
                child: Text(_originTagText(flagByLabel[origin], origin)),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
