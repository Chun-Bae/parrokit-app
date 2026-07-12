import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io';
import 'package:file_saver/file_saver.dart';
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';

import 'package:parrokit/features/content-studio/hub/presentation/studio_hub_provider.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';

import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:parrokit/core/shared/theme/app_colors.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/features/content-studio/tts/domain/repositories/tts_generation_repository.dart';
import 'package:parrokit/features/content-studio/tts/presentation/providers/tts_provider.dart';
import 'package:parrokit/features/content-studio/tts/domain/models/tts_language.dart';

import 'package:parrokit/features/content-studio/tts/presentation/sections/tts_provider_selector.dart';
import 'package:parrokit/features/content-studio/tts/presentation/widgets/tts_studio_hero.dart';
import 'package:parrokit/features/content-studio/tts/presentation/widgets/tts_panel.dart';
import 'package:parrokit/features/content-studio/tts/presentation/widgets/tts_option_row.dart';
import 'package:parrokit/features/content-studio/tts/presentation/widgets/tts_slider_preview.dart';
import 'package:parrokit/features/content-studio/tts/presentation/widgets/tts_audio_player_widget.dart';
import 'package:parrokit/features/content-studio/tts/data/repositories/tts_voice_cache.dart';
import 'package:parrokit/features/content-studio/tts/domain/models/tts_elevenlabs_models.dart';
import 'package:parrokit/features/content-studio/tts/presentation/widgets/tts_elevenlabs_model_selection_sheet.dart';
import 'package:parrokit/features/content-studio/tts/presentation/widgets/tts_elevenlabs_voice_selection_sheet.dart';
import 'package:parrokit/features/content-studio/tts/presentation/widgets/tts_language_selection_sheet.dart';
import 'package:parrokit/features/content-studio/tts/presentation/widgets/tts_voice_selection_sheet.dart';
import 'package:parrokit/features/content-studio/tts/presentation/widgets/tts_gemini_voice_selection_sheet.dart';
import 'package:parrokit/features/content-studio/tts/presentation/widgets/tts_gemini_model_selection_sheet.dart';
import 'package:parrokit/features/content-studio/tts/domain/models/tts_gemini_models.dart';

class TtsScreen extends StatelessWidget {
  const TtsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _TtsScreenContent();
  }
}

class _TtsScreenContent extends StatefulWidget {
  const _TtsScreenContent();

  @override
  State<_TtsScreenContent> createState() => _TtsScreenContentState();
}

class _TtsScreenContentState extends State<_TtsScreenContent> {
  late final TextEditingController _textController;
  Timer? _debounce;
  final _languageIdentifier = LanguageIdentifier(confidenceThreshold: 0.5);

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<TtsProvider>().fetchAvailableVoices();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _languageIdentifier.close();
    _textController.dispose();
    super.dispose();
  }

  void _onTextChanged(String text, TtsProvider provider) {
    provider.updateText(text);

    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (text.trim().isNotEmpty) {
        try {
          AppLogger.d('[TTS][LanguageDetection] attempt text="$text"');
          final languageCode = await _languageIdentifier.identifyLanguage(text);
          AppLogger.d('[TTS][LanguageDetection] identified code=$languageCode');
          
          if (languageCode != 'und') {
            final ttsLang = getLanguageByMlKitCode(languageCode);
            AppLogger.d('[TTS][LanguageDetection] mapped ttsLang=${ttsLang?.ttsCode} displayName=${ttsLang?.displayName}');
            
            if (ttsLang != null && mounted) {
              AppLogger.d('[TTS][LanguageDetection] update provider prevLanguage=${provider.language} newLanguage=${ttsLang.ttsCode}');
              if (provider.language != ttsLang.ttsCode) {
                provider.updateLanguage(ttsLang.ttsCode);
                provider.fetchAvailableVoices();
              }
            }
          }
        } catch (e) {
          AppLogger.e('[TTS][LanguageDetection] failed', error: e);
        }
      }
    });
  }

  void _showLanguageSelectionSheet(BuildContext context, TtsProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TtsLanguageSelectionSheet(provider: provider),
    );
  }

  void _showVoiceSelectionSheet(BuildContext context, TtsProvider provider) {
    if (provider.availableVoices.isEmpty) {
      provider.fetchAvailableVoices();
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TtsVoiceSelectionSheet(provider: provider),
    );
  }

  void _showGeminiVoiceSelectionSheet(BuildContext context, TtsProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TtsGeminiVoiceSelectionSheet(provider: provider),
    );
  }

  void _showGeminiModelSelectionSheet(BuildContext context, TtsProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TtsGeminiModelSelectionSheet(provider: provider),
    );
  }

  void _showElevenLabsVoiceSelectionSheet(BuildContext context, TtsProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TtsElevenLabsVoiceSelectionSheet(provider: provider),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mutedText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    final provider = context.watch<TtsProvider>();

    if (_textController.text != provider.text) {
      final newText = provider.text;
      _textController.value = _textController.value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
      
      // 외부(챗봇 등)에서 텍스트가 주입된 경우 언어 감지 트리거
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _onTextChanged(newText, context.read<TtsProvider>());
        }
      });
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            24,
          ),
          children: [
            const TtsStudioHero(
              icon: Icons.graphic_eq_rounded,
              title: '텍스트를 자연스러운 음성으로',
              description: '스크립트와 보이스 톤을 정하면 학습 클립용 음성 파일을 만들 수 있습니다.',
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            TtsPanel(
              title: '스크립트',
              trailing: Text(
                '${provider.text.length} / 240',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: mutedText,
                ),
              ),
              child: TextField(
                controller: _textController,
                minLines: 7,
                maxLines: 10,
                maxLength: 240,
                onChanged: (val) => _onTextChanged(val, provider),
                decoration: const InputDecoration(
                  hintText: '예: 오늘 배울 표현은 “Could you give me a hand?” 입니다.',
                  alignLabelWithHint: true,
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TtsProviderSelector(
              selectedType: provider.providerType,
              onTypeChanged: provider.updateProviderType,
            ),
            const SizedBox(height: AppSpacing.lg),
            TtsPanel(
              title: '보이스 설정',
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      sizeFactor: animation,
                      axisAlignment: 0.0,
                      child: child,
                    ),
                  );
                },
                child: () {
                  switch (provider.providerType) {
                    case TtsProviderType.google:
                      return Column(
                        key: const ValueKey('google_options'),
                        children: [
                          TtsOptionRow(
                            icon: Icons.language_rounded,
                            title: '언어',
                            value: getLanguageByTtsCode(provider.language).displayName,
                            accentColor: theme.colorScheme.primary,
                            onTap: () => _showLanguageSelectionSheet(context, provider),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TtsOptionRow(
                            icon: Icons.record_voice_over_rounded,
                            title: '보이스',
                            value: provider.isLoadingVoices 
                                ? '목록 불러오는 중...' 
                                : (provider.voiceId.isEmpty ? '선택 (기본값)' : provider.voiceId),
                            accentColor: theme.colorScheme.primary,
                            onTap: () => _showVoiceSelectionSheet(context, provider),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TtsSliderPreview(
                            label: '속도 (0.25배 ~ 4.0배)',
                            valueText: '${provider.speakingRate.toStringAsFixed(2)}x',
                            value: provider.speakingRate,
                            min: 0.25,
                            max: 4.0,
                            activeColor: theme.colorScheme.primary,
                            onChanged: provider.updateSpeakingRate,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TtsSliderPreview(
                            label: '톤 (-20 ~ 20)',
                            valueText: provider.pitch > 0 ? '+${provider.pitch.toStringAsFixed(1)}' : provider.pitch.toStringAsFixed(1),
                            value: provider.pitch,
                            min: -20.0,
                            max: 20.0,
                            activeColor: theme.colorScheme.primary,
                            onChanged: provider.updatePitch,
                          ),
                        ],
                      );
                    case TtsProviderType.elevenlabs:
                      return Column(
                        key: const ValueKey('elevenlabs_options'),
                        children: [
                          TtsOptionRow(
                            icon: Icons.auto_awesome_rounded,
                            title: '모델',
                            value: elevenLabsModels.firstWhere(
                              (m) => m.id == (provider.modelId ?? 'eleven_multilingual_v2'),
                              orElse: () => elevenLabsModels.first,
                            ).name,
                            accentColor: AppColors.secondary,
                            onTap: () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => TtsElevenLabsModelSelectionSheet(provider: provider),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TtsOptionRow(
                            icon: Icons.record_voice_over_rounded,
                            title: '보이스',
                            value: provider.voiceId.isEmpty 
                                ? '선택 (기본값)' 
                                : (TtsVoiceCache().elevenLabsVoices?.firstWhere(
                                      (v) => v.id == provider.voiceId,
                                      orElse: () => TtsElevenLabsVoice(id: provider.voiceId, name: provider.voiceId, category: '', language: ''),
                                    ).name ?? provider.voiceId),
                            accentColor: AppColors.secondary,
                            onTap: () => _showElevenLabsVoiceSelectionSheet(context, provider),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TtsSliderPreview(
                            label: '안정성 (Stability)',
                            valueText: '${(provider.elevenLabsStability * 100).toInt()}%',
                            value: provider.elevenLabsStability,
                            activeColor: AppColors.secondary,
                            onChanged: provider.updateElevenLabsStability,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TtsSliderPreview(
                            label: '유사도 (Clarity)',
                            valueText: '${(provider.elevenLabsSimilarityBoost * 100).toInt()}%',
                            value: provider.elevenLabsSimilarityBoost,
                            activeColor: AppColors.secondary,
                            onChanged: provider.updateElevenLabsSimilarityBoost,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TtsSliderPreview(
                            label: '스타일 과장 (Style)',
                            valueText: '${(provider.elevenLabsStyle * 100).toInt()}%',
                            value: provider.elevenLabsStyle,
                            activeColor: AppColors.secondary,
                            onChanged: provider.updateElevenLabsStyle,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '스피커 부스트 (Speaker Boost)',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Switch(
                                value: provider.elevenLabsUseSpeakerBoost,
                                activeTrackColor: AppColors.secondary.withValues(alpha: 0.5),
                                activeThumbColor: AppColors.secondary,
                                onChanged: provider.updateElevenLabsUseSpeakerBoost,
                              ),
                            ],
                          ),
                        ],
                      );
                    case TtsProviderType.gemini:
                      return Column(
                        key: const ValueKey('gemini_options'),
                        children: [
                          TtsOptionRow(
                            icon: Icons.auto_awesome_rounded,
                            title: '모델',
                            value: geminiModels.firstWhere(
                              (m) => m.id == (provider.modelId ?? 'gemini-2.5-flash-preview-tts'),
                              orElse: () => geminiModels.first,
                            ).name,
                            accentColor: const Color(0xFF9B72CB),
                            isGemini: true,
                            onTap: () => _showGeminiModelSelectionSheet(context, provider),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TtsOptionRow(
                            icon: Icons.record_voice_over_rounded,
                            title: '보이스 에이전트',
                            value: geminiVoices.firstWhere(
                              (v) => v.id == (provider.voiceId.isEmpty ? 'Aoede' : provider.voiceId),
                              orElse: () => geminiVoices.first,
                            ).name,
                            accentColor: const Color(0xFF9B72CB),
                            isGemini: true,
                            onTap: () => _showGeminiVoiceSelectionSheet(context, provider),
                          ),
                        ],
                      );
                  }
                }(),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TtsPanel(
              title: '생성 미리보기',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TtsAudioPlayerWidget(provider: provider),
                  if (provider.errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                      child: Text(
                        provider.errorMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '예상 ${provider.estimatedCost} 패롯',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: mutedText,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: provider.providerType == TtsProviderType.gemini &&
                              !(provider.isGenerating || provider.text.trim().isEmpty)
                          ? AppColors.geminiGradient
                          : null,
                    ),
                    child: FilledButton.icon(
                      onPressed: provider.isGenerating || provider.text.trim().isEmpty
                          ? null
                          : () => provider.generateTts(),
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.disabled)) {
                            return theme.disabledColor.withValues(alpha: 0.1);
                          }
                          if (provider.providerType == TtsProviderType.gemini) {
                            return Colors.transparent;
                          }
                          return provider.providerType == TtsProviderType.google
                              ? theme.colorScheme.primary
                              : AppColors.secondary;
                        }),
                        shadowColor: provider.providerType == TtsProviderType.gemini
                            ? const WidgetStatePropertyAll(Colors.transparent)
                            : null,
                      ),
                      icon: provider.isGenerating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white70,
                              ),
                            )
                          : const Icon(Icons.auto_awesome_rounded),
                      label: const Text('음성 생성'),
                    ),
                  ),
                ],
              ),
            ),
            if (provider.generatedFilePath != null) ...[
              const SizedBox(height: AppSpacing.lg),
              TtsPanel(
                title: '생성 결과 관리',
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final hubProvider = context.read<StudioHubProvider>();
                          hubProvider.sendAudioToCaptioning(provider.generatedFilePath!);
                        },
                        icon: const Icon(Icons.subtitles),
                        label: const Text('자막 생성'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            final bytes = await File(provider.generatedFilePath!).readAsBytes();
                            await FileSaver.instance.saveFile(
                              name: 'Parrokit_TTS_\${DateTime.now().millisecondsSinceEpoch}',
                              bytes: bytes,
                              ext: 'mp3',
                              mimeType: MimeType.mp3,
                            );
                            if (context.mounted) {
                              showToast('음성 파일이 저장되었습니다.');
                            }
                          } catch (e) {
                            if (context.mounted) {
                              showToast('저장 중 오류가 발생했습니다.');
                            }
                          }
                        },
                        icon: const Icon(Icons.save_alt_rounded),
                        label: const Text('저장'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => provider.clearGeneratedAudio(),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('지우기'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
