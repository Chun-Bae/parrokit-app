import 'package:parrokit/core/shared/utils/action_failed_text.dart';
import 'package:parrokit/features/content-studio/tts/presentation/tts_provider_text.dart';
import 'package:parrokit/features/content-studio/tts/domain/models/tts_google_models.dart';
import 'package:parrokit/features/content-studio/tts/presentation/tts_file_name.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/core/content/parrot_cost_text.dart';
import 'package:parrokit/core/shared/utils/speed_label.dart';
import 'package:parrokit/features/content-studio/hub/presentation/studio_layout.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/features/content-studio/shared/studio_colors.dart';
import 'package:provider/provider.dart';
import 'package:file_saver/file_saver.dart';

import 'package:parrokit/features/content-studio/hub/presentation/studio_hub_provider.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';

import 'package:parrokit/core/shared/theme/app_colors.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/features/content-studio/tts/domain/repositories/tts_generation_repository.dart';
import 'package:parrokit/features/content-studio/tts/presentation/providers/tts_provider.dart';
import 'package:parrokit/features/content-studio/tts/domain/models/tts_language.dart';

import 'package:parrokit/features/content-studio/tts/presentation/sections/tts_provider_selector.dart';
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
import 'package:parrokit/core/shared/widgets/app_bottom_sheet.dart';

/// 목소리 목록을 못 불러왔을 때, 그래도 만들 수 있다는 것을 알린다.
/// 서버가 그 언어의 기본 목소리를 고른다(5차).
const String ttsDefaultVoiceNotice = '목소리 목록을 못 불러왔어요. 그대로 만들면 기본 목소리로 읽어 줘요.';

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
    _textController.dispose();
    super.dispose();
  }

  void _onTextChanged(String text, TtsProvider provider) {
    // ML Kit를 다시 연결할 때까지 사용자가 선택한 TTS 언어를 유지한다.
    provider.updateText(text);
  }

  void _showLanguageSelectionSheet(BuildContext context, TtsProvider provider) {
    showAppSheet(
      context: context,
      builder: (context) => TtsLanguageSelectionSheet(provider: provider),
    );
  }

  void _showVoiceSelectionSheet(BuildContext context, TtsProvider provider) {
    if (provider.availableVoices.isEmpty) {
      provider.fetchAvailableVoices();
    }
    showAppSheet(
      context: context,
      builder: (context) => TtsVoiceSelectionSheet(provider: provider),
    );
  }

  void _showGeminiVoiceSelectionSheet(
      BuildContext context, TtsProvider provider) {
    showAppSheet(
      context: context,
      builder: (context) => TtsGeminiVoiceSelectionSheet(provider: provider),
    );
  }

  void _showGeminiModelSelectionSheet(
      BuildContext context, TtsProvider provider) {
    showAppSheet(
      context: context,
      builder: (context) => TtsGeminiModelSelectionSheet(provider: provider),
    );
  }

  void _showElevenLabsVoiceSelectionSheet(
      BuildContext context, TtsProvider provider) {
    showAppSheet(
      context: context,
      builder: (context) =>
          TtsElevenLabsVoiceSelectionSheet(provider: provider),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedText = context.tokens.textSecondary;
    final provider = context.watch<TtsProvider>();
    context.read<StudioHubProvider?>()?.setWorkCheck(
        'tts',
        () =>
            mounted &&
            (_textController.text.trim().isNotEmpty ||
                provider.generatedFilePath != null));

    if (_textController.text != provider.text) {
      final newText = provider.text;
      _textController.value = _textController.value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
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
            24 + kStudioSwitchBarSpace,
          ),
          children: [
            // 앱바 'TTS 생성'과 콘텐츠 제작 첫 화면이 같은 말을 해서 큰 소개
            // 상자(TtsStudioHero)는 없앴다(4차). 스크립트 입력부터 보인다.
            TtsPanel(
              // 앱의 다른 곳은 '글·문장'이라 부른다. '스크립트'는 여기만
              // 쓰던 말이다(5차).
              title: '읽을 글',
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
                  hintText: '예: 오늘 배울 표현은 “Could you give me a hand?”예요.',
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
            const SizedBox(height: AppSpacing.sm),
            // 회사 이름만 셋 있으면 무엇이 다른지 알 수 없다(5차 413).
            Text(
              ttsProviderBlurb(provider.providerType),
              key: const ValueKey('tts-provider-blurb'),
              style: theme.textTheme.bodySmall?.copyWith(color: mutedText),
            ),
            const SizedBox(height: AppSpacing.lg),
            TtsPanel(
              title: '목소리 설정',
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
                            value: getLanguageByTtsCode(provider.language)
                                .displayName,
                            accentColor: theme.colorScheme.primary,
                            onTap: () =>
                                _showLanguageSelectionSheet(context, provider),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TtsOptionRow(
                            icon: Icons.record_voice_over_rounded,
                            title: '목소리',
                            value: provider.isLoadingVoices
                                ? '목록 불러오는 중...'
                                : provider.voicesFailed
                                    // 실패해도 '선택 (기본값)'으로 보여
                                    // 목록이 없는 것인지 못 가져온 것인지
                                    // 알 수 없었다(5차).
                                    ? '목록을 불러오지 못했어요'
                                    : (provider.voiceId.isEmpty
                                        ? '기본 목소리'
                                        // 전에는 'en-US-Wavenet-A'가 그대로
                                        // 떴다(5차 412).
                                        : googleVoiceLabel(
                                            provider.voiceId,
                                            ssmlGender: provider.availableVoices
                                                .cast<Map<String, dynamic>?>()
                                                .firstWhere(
                                                  (v) =>
                                                      v?['name'] ==
                                                      provider.voiceId,
                                                  orElse: () => null,
                                                )?['ssmlGender']
                                                ?.toString(),
                                          )),
                            accentColor: theme.colorScheme.primary,
                            onTap: () =>
                                _showVoiceSelectionSheet(context, provider),
                          ),
                          _MoreOptions(children: [
                            TtsSliderPreview(
                              // 범위는 슬라이더가 보여 준다. 제목은 다른
                              // 화면과 같은 '속도'(5차).
                              label: '속도',
                              valueText: speedLabel(provider.speakingRate),
                              value: provider.speakingRate,
                              min: 0.25,
                              max: 4.0,
                              activeColor: theme.colorScheme.primary,
                              onChanged: provider.updateSpeakingRate,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TtsSliderPreview(
                              label: '목소리 높낮이',
                              valueText: provider.pitch > 0
                                  ? '+${provider.pitch.toStringAsFixed(1)}'
                                  : provider.pitch.toStringAsFixed(1),
                              value: provider.pitch,
                              min: -20.0,
                              max: 20.0,
                              activeColor: theme.colorScheme.primary,
                              onChanged: provider.updatePitch,
                            ),
                          ]),
                        ],
                      );
                    case TtsProviderType.elevenlabs:
                      return Column(
                        key: const ValueKey('elevenlabs_options'),
                        children: [
                          TtsOptionRow(
                            icon: Icons.auto_awesome_rounded,
                            title: '모델',
                            value: elevenLabsModels
                                .firstWhere(
                                  (m) =>
                                      m.id ==
                                      (provider.modelId ??
                                          'eleven_multilingual_v2'),
                                  orElse: () => elevenLabsModels.first,
                                )
                                .name,
                            accentColor: context.tokens.secondary,
                            onTap: () => showAppSheet(
                              context: context,
                              builder: (context) =>
                                  TtsElevenLabsModelSelectionSheet(
                                      provider: provider),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TtsOptionRow(
                            icon: Icons.record_voice_over_rounded,
                            title: '목소리',
                            value: provider.voiceId.isEmpty
                                // 구글 쪽과 같은 말로(5차 412).
                                ? '기본 목소리'
                                : (TtsVoiceCache()
                                        .elevenLabsVoices
                                        ?.firstWhere(
                                          (v) => v.id == provider.voiceId,
                                          orElse: () => TtsElevenLabsVoice(
                                              id: provider.voiceId,
                                              name: provider.voiceId,
                                              category: '',
                                              language: ''),
                                        )
                                        .name ??
                                    provider.voiceId),
                            accentColor: context.tokens.secondary,
                            onTap: () => _showElevenLabsVoiceSelectionSheet(
                                context, provider),
                          ),
                          _MoreOptions(children: [
                            TtsSliderPreview(
                              // 영어 이름을 괄호로 덧붙이던 것을 뺐다.
                              // 무엇을 바꾸는지로 부른다(5차 411).
                              label: '또박또박 말하기',
                              valueText:
                                  '${(provider.elevenLabsStability * 100).toInt()}%',
                              value: provider.elevenLabsStability,
                              activeColor: context.tokens.secondary,
                              onChanged: provider.updateElevenLabsStability,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TtsSliderPreview(
                              label: '목소리 닮기',
                              valueText:
                                  '${(provider.elevenLabsSimilarityBoost * 100).toInt()}%',
                              value: provider.elevenLabsSimilarityBoost,
                              activeColor: context.tokens.secondary,
                              onChanged:
                                  provider.updateElevenLabsSimilarityBoost,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TtsSliderPreview(
                              label: '감정 살리기',
                              valueText:
                                  '${(provider.elevenLabsStyle * 100).toInt()}%',
                              value: provider.elevenLabsStyle,
                              activeColor: context.tokens.secondary,
                              onChanged: provider.updateElevenLabsStyle,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '또렷하게 키우기',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Switch(
                                  value: provider.elevenLabsUseSpeakerBoost,
                                  activeTrackColor: context.tokens.secondary
                                      .withValues(alpha: 0.5),
                                  activeThumbColor: context.tokens.secondary,
                                  onChanged:
                                      provider.updateElevenLabsUseSpeakerBoost,
                                ),
                              ],
                            ),
                          ]),
                        ],
                      );
                    case TtsProviderType.gemini:
                      return Column(
                        key: const ValueKey('gemini_options'),
                        children: [
                          TtsOptionRow(
                            icon: Icons.auto_awesome_rounded,
                            title: '모델',
                            value: geminiModels
                                .firstWhere(
                                  (m) =>
                                      m.id ==
                                      (provider.modelId ??
                                          defaultGeminiTtsModelId),
                                  orElse: () => geminiModels.first,
                                )
                                .name,
                            accentColor: StudioColors.geminiPurple,
                            isGemini: true,
                            onTap: () => _showGeminiModelSelectionSheet(
                                context, provider),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TtsOptionRow(
                            icon: Icons.record_voice_over_rounded,
                            title: '목소리 에이전트',
                            value: geminiVoices
                                .firstWhere(
                                  (v) =>
                                      v.id ==
                                      (provider.voiceId.isEmpty
                                          ? 'Aoede'
                                          : provider.voiceId),
                                  orElse: () => geminiVoices.first,
                                )
                                .name,
                            accentColor: StudioColors.geminiPurple,
                            isGemini: true,
                            onTap: () => _showGeminiVoiceSelectionSheet(
                                context, provider),
                          ),
                        ],
                      );
                  }
                }(),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TtsPanel(
              title: '미리 듣기',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TtsAudioPlayerWidget(provider: provider),
                  if (provider.errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                      child: Text(
                        provider.errorMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: context.tokens.primarySubtle,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt_rounded,
                                size: 18, color: theme.colorScheme.primary),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              '예상 ${provider.estimatedCost} 패롯',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // 모자라면 누른 뒤에야 시트가 떴다. 누르기 전에 알려 준다
                  // (5차, 자동 자막과 같은 말).
                  if (parrotShortfallLine(
                    cost: provider.estimatedCost,
                    coins: context.watch<UserProvider>().coins,
                  )
                      case final short?) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      short,
                      key: const ValueKey('tts-short-line'),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.error),
                    ),
                  ],
                  // 목록을 못 불러와도 만들 수는 있다. 서버가 그 언어의 기본
                  // 목소리를 고른다(contentStudioAi의 defaultVoice). 버튼만
                  // 켜져 있으면 눌러도 되는지 몰라 망설인다(5차).
                  if (provider.voicesFailed) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      ttsDefaultVoiceNotice,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      gradient:
                          provider.providerType == TtsProviderType.gemini &&
                                  !(provider.isGenerating ||
                                      provider.text.trim().isEmpty)
                              ? AppColors.geminiGradient
                              : null,
                    ),
                    child: FilledButton.icon(
                      onPressed:
                          provider.isGenerating || provider.text.trim().isEmpty
                              ? null
                              : () => provider.generateTts(),
                      style: ButtonStyle(
                        backgroundColor:
                            WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.disabled)) {
                            return theme.disabledColor.withValues(alpha: 0.1);
                          }
                          if (provider.providerType == TtsProviderType.gemini) {
                            return Colors.transparent;
                          }
                          return provider.providerType == TtsProviderType.google
                              ? theme.colorScheme.primary
                              : context.tokens.secondary;
                        }),
                        shadowColor: provider.providerType ==
                                TtsProviderType.gemini
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
                      // 화면 제목·아래 탭·보관함 추가 시트와 같은 이름으로(5차).
                      label: const Text('음성 만들기'),
                    ),
                  ),
                ],
              ),
            ),
            if (provider.generatedFilePath != null) ...[
              const SizedBox(height: AppSpacing.lg),
              TtsPanel(
                // '생성 결과 관리'는 무엇을 할 수 있는지 말하지 않았다.
                // 다음에 할 일을 이름으로 적는다(5차 411, 사용자 요청).
                title: '만든 음성으로 할 일',
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const ValueKey('tts-make-clip'),
                        onPressed: () {
                          final hubProvider = context.read<StudioHubProvider>();
                          hubProvider.sendAudioToCaptioning(
                              provider.generatedFilePath!);
                        },
                        icon: const Icon(Icons.subtitles_rounded),
                        // 전에는 '자막 생성'이라 눌러도 어디로 가는지 몰랐다.
                        label: const Text('자막 넣어 클립 만들기'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        key: const ValueKey('tts-save-mp3'),
                        onPressed: () async {
                          try {
                            final bytes =
                                await File(provider.generatedFilePath!)
                                    .readAsBytes();
                            await FileSaver.instance.saveFile(
                              // 전에는 작은따옴표 안에서 \$를 써서 파일
                              // 이름이 'Parrokit_TTS_${DateTime.now()...}'
                              // 그대로 저장됐다(5차 411).
                              name: ttsFileName(DateTime.now()),
                              bytes: bytes,
                              ext: 'mp3',
                              mimeType: MimeType.mp3,
                            );
                            if (context.mounted) {
                              showToast('음성 파일을 저장했어요.');
                            }
                          } catch (e) {
                            if (context.mounted) {
                              showToast(saveFailedMessage);
                            }
                          }
                        },
                        icon: const Icon(Icons.save_alt_rounded),
                        // '저장'만으로는 어디에 저장되는지 몰랐다.
                        label: const Text('mp3 파일로 내려받기'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        key: const ValueKey('tts-clear'),
                        onPressed: () => provider.clearGeneratedAudio(),
                        icon: const Icon(Icons.refresh_rounded),
                        // '지우기'는 무엇이 지워지는지 몰랐다. 다시 만들려고
                        // 누르는 자리다.
                        label: const Text('지우고 다시 만들기'),
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

/// 자주 바꾸지 않는 설정을 접어 둔다(5차 411, 사용자 요청).
///
/// 전에는 속도·높낮이·안정성·유사도·스타일·부스트가 모두 펼쳐져 있어서,
/// 글을 쓰고 목소리만 고르면 되는 사람도 슬라이더 여섯 개를 지나야 했다.
class _MoreOptions extends StatelessWidget {
  const _MoreOptions({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      // 접기 줄에 테두리를 두지 않는다.
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: const ValueKey('tts-more-options'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: AppSpacing.sm),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        title: Text(
          '자세한 설정',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.tokens.textSecondary,
          ),
        ),
        children: children,
      ),
    );
  }
}
