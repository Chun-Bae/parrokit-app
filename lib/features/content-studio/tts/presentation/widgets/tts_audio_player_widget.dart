import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:just_audio/just_audio.dart';
import 'package:parrokit/core/shared/theme/app_colors.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:parrokit/features/content-studio/tts/domain/repositories/tts_generation_repository.dart';
import 'package:parrokit/features/content-studio/tts/presentation/providers/tts_provider.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';

class TtsAudioPlayerWidget extends StatefulWidget {
  const TtsAudioPlayerWidget({super.key, required this.provider});

  final TtsProvider provider;

  @override
  State<TtsAudioPlayerWidget> createState() => _TtsAudioPlayerWidgetState();
}

class _TtsAudioPlayerWidgetState extends State<TtsAudioPlayerWidget> {
  late AudioPlayer _player;
  bool _isPlaying = false;
  bool _isDragging = false;
  bool _wasPlayingBeforeDrag = false;
  String? _currentFilePath;
  Duration _position = Duration.zero;
  Duration _dragPosition = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing &&
              state.processingState != ProcessingState.completed;
        });
      }
    });
    _player.positionStream.listen((position) {
      if (mounted && !_isDragging) {
        setState(() => _position = position);
      }
    });
    _player.durationStream.listen((duration) {
      if (mounted) setState(() => _duration = duration ?? Duration.zero);
    });
  }

  @override
  void didUpdateWidget(covariant TtsAudioPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.provider.isGenerating) {
      _player.stop();
      _currentFilePath = null;
    } else if (widget.provider.generatedFilePath != null &&
        widget.provider.generatedFilePath != _currentFilePath) {
      _currentFilePath = widget.provider.generatedFilePath;
      _player.setFilePath(_currentFilePath!);
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _togglePlay() async {
    if (_currentFilePath == null) return;

    if (_isPlaying) {
      await _player.pause();
    } else {
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      await _player.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mutedText = context.tokens.textSecondary;

    return Container(
      height: 76,
      decoration: BoxDecoration(
        color: context.tokens.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          const SizedBox(width: AppSpacing.lg),
          GestureDetector(
            onTap: widget.provider.isGenerating ||
                    widget.provider.generatedFilePath == null
                ? null
                : _togglePlay,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: widget.provider.generatedFilePath != null &&
                        widget.provider.providerType ==
                            TtsProviderType.gemini &&
                        !widget.provider.isGenerating
                    ? AppColors.geminiGradient
                    : null,
                color: widget.provider.isGenerating
                    ? context.tokens.disabled
                    : (widget.provider.generatedFilePath != null
                        ? (widget.provider.providerType ==
                                TtsProviderType.google
                            ? theme.colorScheme.primary
                            : (widget.provider.providerType ==
                                    TtsProviderType.elevenlabs
                                ? context.tokens.secondary
                                : null))
                        : context.tokens.disabled),
              ),
              child: Center(
                child: widget.provider.isGenerating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                      ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.provider.isGenerating
                      ? '음성을 생성하는 중...'
                      : (widget.provider.generatedFilePath != null
                          ? '음성 생성 완료'
                          : '아직 생성된 음성이 없습니다'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                if (widget.provider.generatedFilePath != null &&
                    !widget.provider.isGenerating)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 36,
                        child: Text(
                          _formatDuration(
                              _isDragging ? _dragPosition : _position),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: mutedText,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LayoutBuilder(
                              builder: (context, constraints) {
                                return GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onHorizontalDragStart: (details) {
                                    if (_duration > Duration.zero) {
                                      _wasPlayingBeforeDrag = _isPlaying;
                                      if (_wasPlayingBeforeDrag) {
                                        _player.pause();
                                      }
                                      setState(() {
                                        _isDragging = true;
                                        final percent =
                                            (details.localPosition.dx /
                                                    constraints.maxWidth)
                                                .clamp(0.0, 1.0);
                                        _dragPosition = Duration(
                                            milliseconds:
                                                (_duration.inMilliseconds *
                                                        percent)
                                                    .toInt());
                                      });
                                    }
                                  },
                                  onHorizontalDragUpdate: (details) {
                                    if (_duration > Duration.zero &&
                                        _isDragging) {
                                      setState(() {
                                        final percent =
                                            (details.localPosition.dx /
                                                    constraints.maxWidth)
                                                .clamp(0.0, 1.0);
                                        _dragPosition = Duration(
                                            milliseconds:
                                                (_duration.inMilliseconds *
                                                        percent)
                                                    .toInt());
                                      });
                                    }
                                  },
                                  onHorizontalDragEnd: (details) {
                                    if (_isDragging) {
                                      _player.seek(_dragPosition).then((_) {
                                        setState(() => _isDragging = false);
                                        if (_wasPlayingBeforeDrag) {
                                          _player.play();
                                        }
                                      });
                                    }
                                  },
                                  onTapDown: (details) {
                                    if (_duration > Duration.zero) {
                                      final percent =
                                          (details.localPosition.dx /
                                                  constraints.maxWidth)
                                              .clamp(0.0, 1.0);
                                      final newPos = Duration(
                                          milliseconds:
                                              (_duration.inMilliseconds *
                                                      percent)
                                                  .toInt());
                                      _player.seek(newPos);
                                    }
                                  },
                                  child: Builder(
                                    builder: (context) {
                                      final percent =
                                          (_duration.inMilliseconds > 0
                                                  ? (_isDragging
                                                              ? _dragPosition
                                                              : _position)
                                                          .inMilliseconds /
                                                      _duration.inMilliseconds
                                                  : 0.0)
                                              .clamp(0.0, 1.0);
                                      return Container(
                                        height: 24, // 터치 영역 확보
                                        alignment: Alignment.center,
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          alignment: Alignment.centerLeft,
                                          children: [
                                            Container(
                                              height: 4,
                                              width: double.infinity,
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? AppColors
                                                        .dividerSubtleDark
                                                    : context
                                                        .tokens.dividerSubtle,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        AppRadius.track),
                                              ),
                                            ),
                                            FractionallySizedBox(
                                              widthFactor: percent,
                                              child: Container(
                                                height: 4,
                                                decoration: BoxDecoration(
                                                  gradient: widget.provider
                                                              .providerType ==
                                                          TtsProviderType.gemini
                                                      ? AppColors.geminiGradient
                                                      : null,
                                                  color: widget.provider
                                                              .providerType !=
                                                          TtsProviderType.gemini
                                                      ? (widget.provider
                                                                  .providerType ==
                                                              TtsProviderType
                                                                  .google
                                                          ? theme.colorScheme
                                                              .primary
                                                          : context
                                                              .tokens.secondary)
                                                      : null,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          AppRadius.track),
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              left: (constraints.maxWidth *
                                                      percent) -
                                                  6,
                                              child: Container(
                                                width: 12,
                                                height: 12,
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withValues(
                                                              alpha: 0.15),
                                                      blurRadius: 3,
                                                      offset:
                                                          const Offset(0, 1),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 2.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '0:00',
                                    style: context.texts.labelSmall.copyWith(
                                      color: mutedText.withValues(alpha: 0.7),
                                    ),
                                  ),
                                  Text(
                                    _formatDuration(_duration),
                                    style: context.texts.labelSmall.copyWith(
                                      color: mutedText.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                    ],
                  )
                else
                  Text(
                    widget.provider.isGenerating
                        ? '잠시만 기다려주세요.'
                        : '스크립트를 입력하면 결과를 확인합니다.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: mutedText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (widget.provider.generatedFilePath == null ||
              widget.provider.isGenerating)
            const SizedBox(width: AppSpacing.lg),
        ],
      ),
    );
  }
}
