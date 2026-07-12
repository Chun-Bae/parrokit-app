import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import 'package:parrokit/core/shared/theme/app_colors.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/features/content-studio/hub/presentation/studio_hub_provider.dart';
import 'package:parrokit/features/content-studio/chat-bot/presentation/chat_bot_provider.dart';
import 'package:parrokit/features/content-studio/chat-bot/presentation/widgets/chat_bot_sheet.dart';
import 'package:parrokit/features/content-studio/video/domain/models/video_generation_models.dart';
import 'package:parrokit/features/content-studio/video/presentation/video_provider.dart';
import 'package:parrokit/features/content-studio/video/presentation/widgets/video_model_selection_sheet.dart';

class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key});

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  static const int _dialogueMaxLength = 100;
  static const List<String> _recommendationLanguages = [
    '영어',
    '일본어',
    '중국어',
    '스페인어',
  ];
  static const List<String> _recommendationSituations = [
    '카페',
    '여행',
    '친구 대화',
    '회사',
    '쇼핑',
    '병원',
  ];

  late final TextEditingController _dialogueController;
  late final TextEditingController _promptController;

  @override
  void initState() {
    super.initState();
    _dialogueController = TextEditingController();
    _promptController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid = context.read<UserProvider>().currentUser?.id;
      AppLogger.i('[ContentStudio][Video] enter uid=${uid ?? "null"}');
      context.read<VideoProvider>().loadRecentVideos();
    });
  }

  @override
  void dispose() {
    _dialogueController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _openVideoRecommendationFlow() async {
    final selection = await showModalBottomSheet<_VideoRecommendationSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _VideoRecommendationFilterSheet(
        languages: _recommendationLanguages,
        situations: _recommendationSituations,
      ),
    );

    if (!mounted || selection == null) {
      return;
    }

    final initialMessage = _buildRecommendationPrompt(selection);

    context.read<ChatBotProvider>().updateChatbotMode('video');
    await showChatBotSheet(
      context,
      initialMessage: initialMessage,
      onTriggerAction: (tabIndex, actionData) {
        if (tabIndex != 2 || actionData == null) {
          return;
        }
        final provider = context.read<VideoProvider>();
        final script = actionData['script'] as String?;
        final prompt = actionData['prompt'] as String?;
        if (script != null) {
          provider.updateDialogue(script);
        }
        if (prompt != null) {
          provider.updateScenePrompt(prompt);
        }
      },
    );
  }

  String _buildRecommendationPrompt(
    _VideoRecommendationSelection selection,
  ) {
    final language = selection.language?.trim() ?? '';
    final situation = selection.situation?.trim() ?? '';
    return '$language로 $situation 상황의 짧은 회화 영상 추천 프롬프트를 작성해줘.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mutedText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    final provider = context.watch<VideoProvider>();

    if (_dialogueController.text != provider.dialogue) {
      _dialogueController.value = _dialogueController.value.copyWith(
        text: provider.dialogue,
        selection: TextSelection.collapsed(offset: provider.dialogue.length),
      );
    }

    if (_promptController.text != provider.scenePrompt) {
      _promptController.value = _promptController.value.copyWith(
        text: provider.scenePrompt,
        selection: TextSelection.collapsed(offset: provider.scenePrompt.length),
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
            24,
          ),
          children: [
            const _VideoWarningBanner(),
            const SizedBox(height: AppSpacing.lg),
            _VideoPreview(isDark: isDark),
            if (provider.generatedFilePath != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _Panel(
                title: '생성 결과 관리',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '자동 자막 생성으로 넘기면 이 영상을 캡션 편집기 플레이어에 바로 불러옵니다.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: mutedText,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: provider.isExportingForCaptioning
                            ? null
                            : () async {
                                final localPath = await provider
                                    .prepareGeneratedVideoForCaptioning();
                                if (!context.mounted || localPath == null) {
                                  return;
                                }

                                context
                                    .read<StudioHubProvider>()
                                    .sendAudioToCaptioning(localPath);
                              },
                        icon: provider.isExportingForCaptioning
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.subtitles_rounded),
                        label: Text(
                          provider.isExportingForCaptioning
                              ? '준비 중...'
                              : '자동 자막 생성',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sectionGap),
            _Panel(
              title: '대화 스크립트',
              trailing: Text(
                '${provider.dialogue.length} / $_dialogueMaxLength',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: mutedText,
                ),
              ),
              child: TextField(
                controller: _dialogueController,
                minLines: 4,
                maxLines: 8,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(_dialogueMaxLength),
                ],
                onChanged: provider.updateDialogue,
                decoration: const InputDecoration(
                  hintText:
                      '예: A: Could you show me how to say this in English?\nB: Sure, let me give you a simple example.',
                  alignLabelWithHint: true,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _Panel(
              title: '영상 프롬프트',
              trailing: Text(
                '${provider.scenePrompt.length} / 500',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: mutedText,
                ),
              ),
              child: TextField(
                controller: _promptController,
                minLines: 5,
                maxLines: 8,
                onChanged: provider.updateScenePrompt,
                decoration: const InputDecoration(
                  hintText: '예: 책상 위 노트북 화면에 영어 회화 문장이 나타나는 밝은 학습 영상',
                  alignLabelWithHint: true,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _Panel(
              title: '추천 받기',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '챗봇과 대화하면서 대화 스크립트와 영상 프롬프트를 함께 추천받을 수 있어요.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: mutedText,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _openVideoRecommendationFlow,
                      icon: const Icon(Icons.smart_toy_rounded),
                      label: const Text('추천 프롬프트 받기'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _Panel(
              title: '영상 설정',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StyleRow(
                    icon: Icons.auto_awesome_rounded,
                    title: '영상 모델',
                    value: veo31ModelById(provider.model).name,
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        builder: (context) =>
                            VideoModelSelectionSheet(provider: provider),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _OptionGroup(
                    label: '화면비',
                    options: const ['9:16', '1:1', '16:9'],
                    selectedIndex:
                        ['9:16', '1:1', '16:9'].indexOf(provider.ratio),
                    onChanged: (index) =>
                        provider.updateRatio(['9:16', '1:1', '16:9'][index]),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _OptionGroup(
                    label: '길이',
                    options: const ['4초', '5초', '6초', '7초', '8초'],
                    selectedIndex: ![4, 5, 6, 7, 8].contains(provider.duration)
                        ? 1
                        : [4, 5, 6, 7, 8].indexOf(provider.duration),
                    onChanged: (index) =>
                        provider.updateDuration([4, 5, 6, 7, 8][index]),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _StyleRow(
                    icon: Icons.palette_rounded,
                    title: '스타일',
                    value: '교육용 모션',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _StyleRow(
                    icon: Icons.closed_caption_rounded,
                    title: '자막',
                    value: '자동 포함',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _Panel(
              title: '생성 준비',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _InfoPill(
                        icon: Icons.bolt_rounded,
                        text: '예상 ${provider.estimatedCost} 패롯',
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _InfoPill(
                        icon: Icons.schedule_rounded,
                        text: '약 1분',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: provider.isGenerating ||
                              (provider.scenePrompt.trim().isEmpty &&
                                  provider.dialogue.trim().isEmpty)
                          ? null
                          : provider.generateVideo,
                      icon: provider.isGenerating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.movie_creation_rounded),
                      label:
                          Text(provider.isGenerating ? '영상 생성 중...' : '영상 생성'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _RecentVideoPanel(isDark: isDark),
          ],
        ),
      ),
    );
  }
}

class _VideoPreview extends StatefulWidget {
  const _VideoPreview({required this.isDark});

  final bool isDark;

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoRecommendationSelection {
  const _VideoRecommendationSelection({
    this.language,
    this.situation,
  });

  final String? language;
  final String? situation;
}

class _VideoRecommendationFilterSheet extends StatefulWidget {
  const _VideoRecommendationFilterSheet({
    required this.languages,
    required this.situations,
  });

  final List<String> languages;
  final List<String> situations;

  @override
  State<_VideoRecommendationFilterSheet> createState() =>
      _VideoRecommendationFilterSheetState();
}

class _VideoRecommendationFilterSheetState
    extends State<_VideoRecommendationFilterSheet> {
  late final TextEditingController _languageController;
  late final TextEditingController _situationController;
  String? _selectedLanguage;
  String? _selectedSituation;

  @override
  void initState() {
    super.initState();
    _languageController = TextEditingController();
    _situationController = TextEditingController();
    _languageController.addListener(_onRecommendationInputChanged);
    _situationController.addListener(_onRecommendationInputChanged);
    _selectedLanguage = null;
    _selectedSituation = null;
  }

  @override
  void dispose() {
    _languageController.removeListener(_onRecommendationInputChanged);
    _situationController.removeListener(_onRecommendationInputChanged);
    _languageController.dispose();
    _situationController.dispose();
    super.dispose();
  }

  void _onRecommendationInputChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  String? _resolveLanguage() {
    final direct = _languageController.text.trim();
    if (direct.isNotEmpty) {
      return direct;
    }
    return _selectedLanguage;
  }

  String? _resolveSituation() {
    final direct = _situationController.text.trim();
    if (direct.isNotEmpty) {
      return direct;
    }
    return _selectedSituation;
  }

  bool get _hasRecommendationInput {
    return _languageController.text.trim().isNotEmpty &&
        _situationController.text.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mutedText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '추천 조건 선택',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '외국어와 상황을 모두 직접 입력해 주세요. 두 항목이 모두 있어야 추천을 시작할 수 있습니다.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: mutedText,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                _FilterSection(
                  label: '외국어',
                  children: widget.languages.map((language) {
                    final isSelected = _selectedLanguage == language;
                    return ChoiceChip(
                      label: Text(language),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() {
                          _selectedLanguage = isSelected ? null : language;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _languageController,
                  decoration: const InputDecoration(
                    labelText: '외국어 직접 입력',
                    hintText: '예: 프랑스어, 태국어',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _FilterSection(
                  label: '상황',
                  children: widget.situations.map((situation) {
                    final isSelected = _selectedSituation == situation;
                    return ChoiceChip(
                      label: Text(situation),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() {
                          _selectedSituation = isSelected ? null : situation;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _situationController,
                  decoration: const InputDecoration(
                    labelText: '상황 직접 입력',
                    hintText: '예: 공항 체크인, 생일 파티',
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                if (!_hasRecommendationInput) ...[
                  Text(
                    '외국어와 상황을 모두 입력해 주세요.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('닫기'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton(
                        onPressed: _hasRecommendationInput
                            ? () {
                                Navigator.of(context).pop(
                                  _VideoRecommendationSelection(
                                    language: _resolveLanguage(),
                                    situation: _resolveSituation(),
                                  ),
                                );
                              }
                            : null,
                        child: const Text('추천 프롬프트 받기'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.label,
    required this.children,
  });

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color:
                isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: children,
        ),
      ],
    );
  }
}

class _VideoPreviewState extends State<_VideoPreview> {
  VideoPlayerController? _controller;
  String? _lastUrl;
  String? _playerError;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<VideoPlayerController> _createController(String url) async {
    if (url.startsWith('data:')) {
      final match =
          RegExp(r'^data:([^;]+);base64,(.*)$', dotAll: true).firstMatch(url);
      if (match == null) {
        throw FormatException('Invalid data URI');
      }

      final mimeType = match.group(1) ?? 'video/mp4';
      final encoded = match.group(2) ?? '';
      final bytes = base64Decode(encoded);
      final tempDir = await getTemporaryDirectory();
      final extension = mimeType.contains('mp4') ? '.mp4' : '.bin';
      final file = File(
        '${tempDir.path}/parrokit_video_${DateTime.now().microsecondsSinceEpoch}$extension',
      );

      await file.writeAsBytes(bytes, flush: true);
      return VideoPlayerController.file(file);
    }

    if (url.startsWith('file://')) {
      return VideoPlayerController.file(File(Uri.parse(url).toFilePath()));
    }

    if (url.startsWith('/')) {
      return VideoPlayerController.file(File(url));
    }

    return VideoPlayerController.networkUrl(Uri.parse(url));
  }

  void _initPlayer(String url) async {
    if (_lastUrl == url) return;
    _lastUrl = url;
    _playerError = null;

    final oldController = _controller;

    try {
      final newController = await _createController(url);
      _controller = newController;
      await newController.initialize();
      newController.setLooping(true);
      newController.play();
    } catch (e) {
      if (mounted) {
        setState(() {
          _playerError = "영상을 불러올 수 없습니다. 네트워크 연결이나 권한을 확인하세요.";
        });
      }
    }

    oldController?.dispose();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedText =
        widget.isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    final provider = context.watch<VideoProvider>();
    final videoUrl = provider.generatedFilePath;

    if (videoUrl != null && videoUrl.isNotEmpty) {
      _initPlayer(videoUrl);
    } else {
      if (_controller != null) {
        _controller?.dispose();
        _controller = null;
        _lastUrl = null;
      }
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        padding: videoUrl != null
            ? EdgeInsets.zero
            : const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: widget.isDark
              ? AppColors.surfaceContainerDark
              : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: widget.isDark
                ? AppColors.dividerSubtleDark
                : AppColors.dividerSubtle,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Stack(
            children: [
              if (videoUrl == null) ...[
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? AppColors.surfaceContainerHighDark
                          : AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: const Icon(
                          Icons.smart_display_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        '영상 미리보기',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '생성 결과가 이 영역에 표시됩니다.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: mutedText,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ] else if (_controller != null &&
                  _controller!.value.isInitialized) ...[
                Positioned.fill(
                  child: VideoPlayer(_controller!),
                ),
                // Simple play/pause overlay
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_controller!.value.isPlaying) {
                          _controller!.pause();
                        } else {
                          _controller!.play();
                        }
                      });
                    },
                    child: Container(
                      color: Colors.transparent,
                      child: _controller!.value.isPlaying
                          ? const SizedBox.shrink()
                          : Container(
                              color: Colors.black26,
                              child: const Center(
                                child: Icon(Icons.play_arrow_rounded,
                                    color: Colors.white, size: 48),
                              ),
                            ),
                    ),
                  ),
                ),
              ] else if (_playerError != null) ...[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Colors.red, size: 32),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _playerError!,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    this.title,
    this.titleWidget,
    required this.child,
    this.trailing,
  }) : assert(title != null || titleWidget != null);

  final String? title;
  final Widget? titleWidget;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceContainerDark : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isDark ? AppColors.dividerSubtleDark : AppColors.dividerSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: titleWidget ??
                    Text(
                      title!,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _SquareChip extends StatelessWidget {
  const _SquareChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceContainerHighDark
            : AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? AppColors.dividerSubtleDark : AppColors.dividerSubtle,
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _VideoWarningBanner extends StatelessWidget {
  const _VideoWarningBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
            color: isDark ? AppColors.warningDark : AppColors.warning,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '동영상 생성 전 확인',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '스크립트가 영상에 전부 들어가지 않을 수 있습니다.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _VideoWarningPoint(
                  text: '영상 길이와 스크립트 길이는 너무 길지 않도록 적절하게 설정해 주세요.',
                  isDark: isDark,
                ),
                const SizedBox(height: 4),
                _VideoWarningPoint(
                  text: '스크립트가 자연스럽게 반영될 수 있도록 간결하게 작성해 주세요.',
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                Text(
                  '의도와 다르게 생성된 동영상에 대한 책임은 사용자에게 있습니다.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoWarningPoint extends StatelessWidget {
  const _VideoWarningPoint({
    required this.text,
    required this.isDark,
  });

  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '•',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color:
                    isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}

class _RecentVideoPanel extends StatelessWidget {
  const _RecentVideoPanel({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
    final provider = context.watch<VideoProvider>();
    final recentVideos = provider.recentVideos;
    final isOperatorAccount =
        recentVideos.any((record) => record.isOperatorAccount);

    return _Panel(
      titleWidget: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '최근 생성 영상',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          if (isOperatorAccount) ...[
            const SizedBox(width: AppSpacing.sm),
            _SquareChip(label: '운영자 계정'),
          ],
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '일반 계정의 생성 영상은 24시간 동안 보관됩니다. 운영자 계정은 계속 보관되며, 같은 계정으로 다시 들어오면 이어서 볼 수 있습니다.',
            style: theme.textTheme.bodySmall?.copyWith(color: mutedText),
          ),
          const SizedBox(height: AppSpacing.md),
          if (recentVideos.isEmpty)
            Text(
              '아직 저장된 영상이 없습니다.',
              style: theme.textTheme.bodyMedium?.copyWith(color: mutedText),
            )
          else
            Column(
              children: recentVideos.map((record) {
                final hasVideo =
                    record.videoUrl != null && record.videoUrl!.isNotEmpty;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: InkWell(
                    onTap: hasVideo
                        ? () {
                            provider.showSavedVideo(record.videoUrl!);
                          }
                        : null,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surfaceContainerHighDark
                            : AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: isDark
                              ? AppColors.dividerSubtleDark
                              : AppColors.dividerSubtle,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: const Icon(
                              Icons.video_library_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  record.modelId,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  record.prompt,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: mutedText,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${record.retentionLabel} · ${record.status}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: mutedText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (hasVideo)
                            TextButton(
                              onPressed: () {
                                provider.showSavedVideo(record.videoUrl!);
                              },
                              child: const Text('불러오기'),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _OptionGroup extends StatelessWidget {
  const _OptionGroup({
    required this.label,
    required this.options,
    required this.selectedIndex,
    this.onChanged,
  });

  final String label;
  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            for (var i = 0; i < options.length; i++) ...[
              Expanded(
                child: GestureDetector(
                  onTap: onChanged != null ? () => onChanged!(i) : null,
                  child: _ChoiceTile(
                    label: options[i],
                    selected: i == selectedIndex,
                  ),
                ),
              ),
              if (i != options.length - 1) const SizedBox(width: AppSpacing.sm),
            ],
          ],
        ),
      ],
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.selected,
  });

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected
            ? theme.colorScheme.primary
            : isDark
                ? AppColors.surfaceContainerHighDark
                : AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: selected ? Colors.white : theme.colorScheme.onSurface,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StyleRow extends StatelessWidget {
  const _StyleRow({
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.surfaceContainerHighDark
                : AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(value, style: theme.textTheme.bodyMedium),
              const SizedBox(width: AppSpacing.xs),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
            ],
          ),
        ));
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark ? AppColors.primarySubtleDark : AppColors.primarySubtle,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                text,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
