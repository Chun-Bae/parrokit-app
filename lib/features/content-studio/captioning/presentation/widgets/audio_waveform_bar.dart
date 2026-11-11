import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

/// 오디오 파형 그래프 위젯.
///
/// [waveformData]가 null이면 로딩 상태를 표시한다.
/// [waveformData]가 비어있으면 데이터 없음으로 취급하여 숨긴다.
/// 줌 레벨([zoomFactor])에 따라 보여지는 파형 구간(window)이 달라지며,
/// 비디오 재생 시 자동 스크롤을 지원한다.
class AudioWaveformBar extends StatefulWidget {
  const AudioWaveformBar({
    super.key,
    required this.videoController,
    this.waveformData,
    this.overlayRanges = const [],
    this.onOverlayRangeChanged,
    this.onOverlaySelected,
    this.onOverlaySelectionChanged,
    this.showOverlayHandles = true,
    this.initialSelectedOverlaySegmentIndex,
    this.isLoading = false,
    this.zoomFactor = 1.0,
    this.barCount = 100,
    this.height = 48,
    this.playheadRatio = 0.5, // 0.0 ~ 1.0 (0.5 means center)
  });

  /// 재생 위치 동기화에 사용하는 비디오 컨트롤러.
  final VideoPlayerController? videoController;

  /// 실제 오디오 파형 데이터 (고해상도, 0.0 ~ 1.0 정규화 완료)
  final List<double>? waveformData;
  final List<WaveformOverlayRange> overlayRanges;
  final ValueChanged<WaveformOverlayRange>? onOverlayRangeChanged;
  final ValueChanged<int>? onOverlaySelected;
  final ValueChanged<int?>? onOverlaySelectionChanged;
  final bool showOverlayHandles;
  final int? initialSelectedOverlaySegmentIndex;

  final bool isLoading;

  /// 줌 배율 (1.0 = 전체 표시, 값이 클수록 확대됨, 최소 표시 10초)
  final double zoomFactor;

  final int barCount;
  final double height;

  /// 화면 내 재생선(플레이헤드)의 위치 비율 (0.0 ~ 1.0)
  /// 기본값 0.5는 정중앙에 항상 플레이헤드가 위치함을 의미합니다.
  final double playheadRatio;

  @override
  State<AudioWaveformBar> createState() => _AudioWaveformBarState();
}

class _AudioWaveformBarState extends State<AudioWaveformBar> {
  late List<double> _bars;
  int _windowStartMs = 0;
  int _lastPosMs = 0;
  bool _isDragging = false;
  int? _localTargetMs;
  int? _selectedOverlaySegmentIndex;

  List<double>? _cachedFullBars;
  double _cachedZoomFactor = -1;

  @override
  void initState() {
    super.initState();
    _bars = _computeBars();
    _selectedOverlaySegmentIndex = widget.initialSelectedOverlaySegmentIndex;
    widget.videoController?.addListener(_onVideoUpdate);
  }

  @override
  void didUpdateWidget(AudioWaveformBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.zoomFactor != widget.zoomFactor) {
      _updateWindowForZoom();
    }

    if (oldWidget.videoController != widget.videoController) {
      oldWidget.videoController?.removeListener(_onVideoUpdate);
      widget.videoController?.addListener(_onVideoUpdate);
    }

    if (oldWidget.initialSelectedOverlaySegmentIndex !=
        widget.initialSelectedOverlaySegmentIndex) {
      _selectedOverlaySegmentIndex = widget.initialSelectedOverlaySegmentIndex;
    }

    if (oldWidget.waveformData != widget.waveformData) {
      _cachedFullBars = null; // reset cache
      _bars = _computeBars();
    } else if (oldWidget.zoomFactor != widget.zoomFactor) {
      _bars = _computeBars();
    }

    if (_selectedOverlaySegmentIndex != null &&
        !widget.overlayRanges.any(
          (range) => range.segmentIndex == _selectedOverlaySegmentIndex,
        )) {
      _selectedOverlaySegmentIndex = null;
    }
  }

  @override
  void dispose() {
    widget.videoController?.removeListener(_onVideoUpdate);
    super.dispose();
  }

  void _onVideoUpdate() {
    final c = widget.videoController;
    if (c != null && c.value.isInitialized && mounted) {
      if (_isDragging) return;
      final posMs = c.value.position.inMilliseconds;
      final durMs = c.value.duration.inMilliseconds;
      final minDur = math.min(3000.0, durMs.toDouble());
      final windowDurMs =
          (durMs / widget.zoomFactor).clamp(minDur, durMs.toDouble()).toInt();

      final oldStart = _windowStartMs;

      // 실시간 스크롤:
      // 재생 위치를 화면의 playheadRatio 위치에 지속적으로 고정
      _windowStartMs = posMs - (windowDurMs * widget.playheadRatio).toInt();

      final bool posChanged = _lastPosMs != posMs;
      _lastPosMs = posMs;

      // 창 위치가 변했거나 재생 중이면 UI 업데이트
      if (oldStart != _windowStartMs || c.value.isPlaying || posChanged) {
        _bars = _computeBars();
        setState(() {});
      }
    }
  }

  void _updateWindowForZoom() {
    final c = widget.videoController;
    if (c == null || !c.value.isInitialized) return;
    final posMs = c.value.position.inMilliseconds;
    final durMs = c.value.duration.inMilliseconds;
    final minDur = math.min(3000.0, durMs.toDouble());
    final windowDurMs =
        (durMs / widget.zoomFactor).clamp(minDur, durMs.toDouble()).toInt();

    // 현재 재생 위치를 화면의 playheadRatio 위치에 고정하도록 윈도우 이동
    _windowStartMs = posMs - (windowDurMs * widget.playheadRatio).toInt();
  }

  void _updateCacheIfNeeded() {
    if (_cachedFullBars != null && _cachedZoomFactor == widget.zoomFactor) {
      return;
    }

    final raw = widget.waveformData;
    if (raw == null || raw.isEmpty) {
      _cachedFullBars = [];
      _cachedZoomFactor = widget.zoomFactor;
      return;
    }

    final c = widget.videoController;
    if (c == null || !c.value.isInitialized) {
      _cachedFullBars = _downsampleFull(raw, widget.barCount);
      _cachedZoomFactor = widget.zoomFactor;
      return;
    }

    final durMs = c.value.duration.inMilliseconds;
    if (durMs <= 0) {
      _cachedFullBars = [];
      _cachedZoomFactor = widget.zoomFactor;
      return;
    }

    final minDur = math.min(3000.0, durMs.toDouble());
    final windowDurMs =
        (durMs / widget.zoomFactor).clamp(minDur, durMs.toDouble()).toInt();
    final actualWindowDurMs = math.min(windowDurMs, durMs);

    final totalBars = ((durMs / actualWindowDurMs) * widget.barCount).ceil();
    _cachedFullBars = _downsampleFull(raw, totalBars);
    _cachedZoomFactor = widget.zoomFactor;
  }

  List<double> _downsampleFull(List<double> raw, int count) {
    if (count <= 0) return [];
    if (raw.isEmpty) return List.filled(count, 0.0);

    final result = <double>[];
    final step = raw.length / count;
    for (int i = 0; i < count; i++) {
      final s = (i * step).floor();
      final e = ((i + 1) * step).ceil();
      final actualE = math.min(e, raw.length);

      double peak = 0;
      for (int j = s; j < actualE; j++) {
        if (j >= 0 && j < raw.length) {
          if (raw[j] > peak) peak = raw[j];
        }
      }
      result.add(peak.clamp(0.04, 1.0));
    }

    // 전체 범위에서 이미 정규화되어 있으므로, 구간별 재정규화 생략
    return result;
  }

  List<double> _computeBars() {
    _updateCacheIfNeeded();
    return _cachedFullBars ?? [];
  }

  String _formatDuration(int ms) {
    final d = Duration(milliseconds: ms);
    final mm = d.inMinutes.toString().padLeft(2, '0');
    final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    final deci = ((d.inMilliseconds % 1000) ~/ 100).toString();
    return '$mm:$ss.$deci';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 데이터 없고 로딩 중도 아니면 공간 차지 없이 숨김
    if (!widget.isLoading && _bars.isEmpty) {
      return const SizedBox.shrink();
    }

    // 로딩 중 - 스켈레톤 표시
    if (widget.isLoading) {
      return _LoadingSkeleton(height: widget.height, cs: cs);
    }

    final c = widget.videoController;
    int actualWindowDurMs = 0;
    double exactIndex = 0.0;
    int startIndex = 0;
    double fraction = 0.0;

    if (c != null && c.value.isInitialized) {
      final durMs = c.value.duration.inMilliseconds;
      final minDur = math.min(3000.0, durMs.toDouble());
      final windowDurMs =
          (durMs / widget.zoomFactor).clamp(minDur, durMs.toDouble()).toInt();
      actualWindowDurMs = math.min(windowDurMs, durMs);

      if (durMs > 0 && _bars.isNotEmpty) {
        final startRatio = _windowStartMs / durMs;
        exactIndex = startRatio * _bars.length;
        startIndex = exactIndex.floor();
        fraction = exactIndex - startIndex;
      }
    }
    final int endMs = _windowStartMs + actualWindowDurMs;

    return GestureDetector(
      onHorizontalDragStart: _selectedOverlaySegmentIndex == null
          ? (details) => _handleDragStart(context, details)
          : null,
      onHorizontalDragUpdate: _selectedOverlaySegmentIndex == null
          ? (details) => _handleDrag(context, details)
          : null,
      onHorizontalDragEnd: _selectedOverlaySegmentIndex == null
          ? (details) => _handleDragEnd(context, details)
          : null,
      onHorizontalDragCancel: _selectedOverlaySegmentIndex == null
          ? () => _handleDragEnd(context)
          : null,
      onTapDown: _selectedOverlaySegmentIndex == null
          ? (details) => _handleTap(context, details)
          : null,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: widget.height,
            child: ClipRect(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final totalWidth = constraints.maxWidth;
                  final itemWidth = totalWidth / widget.barCount;
                  final barWidth = itemWidth * 0.35;
                  final gap = itemWidth * 0.65;
                  final overlayLayouts = _buildVisibleOverlayLayouts(
                    totalWidth: totalWidth,
                    actualWindowDurMs: actualWindowDurMs,
                    endMs: endMs,
                    videoDurationMs: c?.value.duration.inMilliseconds ?? 0,
                  );

                  return Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: (event) {
                      _handleOverlaySelection(
                        event.localPosition,
                        overlayLayouts,
                      );
                    },
                    child: Stack(
                      children: [
                        OverflowBox(
                          maxWidth: double.infinity,
                          alignment: Alignment.centerLeft,
                          child: Transform.translate(
                            offset: Offset(-fraction * itemWidth, 0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: List.generate(widget.barCount + 2, (i) {
                                final idx = startIndex + i;
                                final barHeightRatio =
                                    (idx >= 0 && idx < _bars.length)
                                        ? _bars[idx]
                                        : 0.04;
                                final barH =
                                    (barHeightRatio * widget.height * 0.85)
                                        .clamp(3.0, widget.height);

                                final playheadIdx = (exactIndex +
                                        widget.barCount * widget.playheadRatio)
                                    .floor();
                                final isPlayed = idx < playheadIdx;
                                final isCurrent = idx == playheadIdx;

                                Color barColor;
                                if (isPlayed) {
                                  barColor = cs.primary;
                                } else if (isCurrent) {
                                  barColor = cs.primary.withValues(alpha: 0.7);
                                } else {
                                  barColor = isDark
                                      ? cs.onSurface.withValues(alpha: 0.18)
                                      : cs.onSurface.withValues(alpha: 0.13);
                                }

                                return Padding(
                                  padding: EdgeInsets.only(right: gap),
                                  child: Container(
                                    width: barWidth,
                                    height: barH,
                                    decoration: BoxDecoration(
                                      color: barColor,
                                      borderRadius:
                                          BorderRadius.circular(barWidth / 2),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                        if (overlayLayouts.isNotEmpty)
                          Positioned.fill(
                            child: Stack(
                              children: overlayLayouts
                                  .map(
                                    (layout) => Positioned(
                                      left: layout.left.clamp(0.0, totalWidth),
                                      top: 0,
                                      bottom: 0,
                                      width:
                                          layout.width.clamp(0.0, totalWidth),
                                      child: _OverlayRangeTile(
                                        range: layout.range,
                                        isSelected:
                                            _selectedOverlaySegmentIndex ==
                                                layout.range.segmentIndex,
                                        totalWidth: totalWidth,
                                        windowStartMs: _windowStartMs,
                                        actualWindowDurMs: actualWindowDurMs,
                                        windowEndMs: endMs,
                                        videoDurationMs:
                                            c?.value.duration.inMilliseconds ??
                                                0,
                                        onChanged: widget.onOverlayRangeChanged,
                                        showHandles: widget.showOverlayHandles,
                                        onSelected: () {
                                          widget.onOverlaySelected
                                              ?.call(layout.range.segmentIndex);
                                          if (widget.onOverlayRangeChanged !=
                                                  null &&
                                              _selectedOverlaySegmentIndex !=
                                                  layout.range.segmentIndex) {
                                            setState(() {
                                              _selectedOverlaySegmentIndex =
                                                  layout.range.segmentIndex;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          if (actualWindowDurMs > 0) ...[
            const SizedBox(height: 2),
            Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(math.max(0, _windowStartMs)),
                      style: context.texts.labelSmall
                          .copyWith(color: cs.onSurface.withValues(alpha: 0.4)),
                    ),
                    Text(
                      _formatDuration(math.min(
                          c?.value.duration.inMilliseconds ?? endMs, endMs)),
                      style: context.texts.labelSmall
                          .copyWith(color: cs.onSurface.withValues(alpha: 0.4)),
                    ),
                  ],
                ),
                Text(
                  _formatDuration(c?.value.position.inMilliseconds ?? 0),
                  style: context.texts.labelSmall.copyWith(color: cs.primary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _handleDragStart(BuildContext context, DragStartDetails details) {
    final c = widget.videoController;
    if (c == null || !c.value.isInitialized) return;
    _isDragging = true;
    _localTargetMs = c.value.position.inMilliseconds;
  }

  void _handleDragEnd(BuildContext context, [dynamic details]) {
    _isDragging = false;
    _localTargetMs = null;
    _onVideoUpdate();
  }

  void _handleDrag(BuildContext context, DragUpdateDetails details) {
    final c = widget.videoController;
    if (c == null || !c.value.isInitialized) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final durMs = c.value.duration.inMilliseconds;
    final minDur = math.min(3000.0, durMs.toDouble());
    final windowDurMs =
        (durMs / widget.zoomFactor).clamp(minDur, durMs.toDouble()).toInt();
    final actualWindowDurMs = math.min(windowDurMs, durMs);

    final msPerPixel = actualWindowDurMs / box.size.width;
    // 왼쪽으로 드래그(음수 delta)하면 시간이 미래로 가야 하므로 -를 붙임
    final deltaMs = -details.delta.dx * msPerPixel;

    final currentMs = _localTargetMs ?? c.value.position.inMilliseconds;
    _localTargetMs = (currentMs + deltaMs).clamp(0, durMs.toDouble()).toInt();

    // UI 로컬 즉시 갱신 (비디오 응답 대기 안 함)
    _windowStartMs =
        _localTargetMs! - (windowDurMs * widget.playheadRatio).toInt();
    _bars = _computeBars();
    setState(() {});

    c.seekTo(Duration(milliseconds: _localTargetMs!));
  }

  void _handleTap(BuildContext context, TapDownDetails details) {
    final c = widget.videoController;
    if (c == null || !c.value.isInitialized) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final durMs = c.value.duration.inMilliseconds;
    final minDur = math.min(3000.0, durMs.toDouble());
    final windowDurMs =
        (durMs / widget.zoomFactor).clamp(minDur, durMs.toDouble()).toInt();
    final actualWindowDurMs = math.min(windowDurMs, durMs);

    final msPerPixel = actualWindowDurMs / box.size.width;
    final targetMs =
        _windowStartMs + (details.localPosition.dx * msPerPixel).toInt();

    c.seekTo(Duration(milliseconds: targetMs.clamp(0, durMs)));
  }

  List<_VisibleOverlayLayout> _buildVisibleOverlayLayouts({
    required double totalWidth,
    required int actualWindowDurMs,
    required int endMs,
    required int videoDurationMs,
  }) {
    if (actualWindowDurMs <= 0 || widget.overlayRanges.isEmpty) {
      return const [];
    }

    final overlays = <_VisibleOverlayLayout>[];
    for (final range in widget.overlayRanges) {
      final visibleStart = math.max(range.startMs, _windowStartMs);
      final visibleEnd = math.min(range.endMs, endMs);
      if (visibleEnd <= visibleStart) continue;

      final left =
          ((visibleStart - _windowStartMs) / actualWindowDurMs) * totalWidth;
      final width =
          ((visibleEnd - visibleStart) / actualWindowDurMs) * totalWidth;

      overlays.add(
        _VisibleOverlayLayout(
          range: range,
          left: left.clamp(0.0, totalWidth),
          width: width.clamp(0.0, totalWidth),
        ),
      );
    }
    return overlays;
  }

  void _handleOverlaySelection(
    Offset localPosition,
    List<_VisibleOverlayLayout> overlayLayouts,
  ) {
    final selected = overlayLayouts
        .where(
          (layout) =>
              localPosition.dx >= layout.left &&
              localPosition.dx <= layout.left + layout.width &&
              localPosition.dy >= 0 &&
              localPosition.dy <= widget.height,
        )
        .map((layout) => layout.range.segmentIndex)
        .toList();

    if (selected.isNotEmpty) {
      final next = selected.last;
      if (_selectedOverlaySegmentIndex != next) {
        setState(() => _selectedOverlaySegmentIndex = next);
      }
      widget.onOverlaySelectionChanged?.call(next);
      return;
    }

    if (_selectedOverlaySegmentIndex != null) {
      setState(() => _selectedOverlaySegmentIndex = null);
    }
    widget.onOverlaySelectionChanged?.call(null);
  }
}

class _VisibleOverlayLayout {
  const _VisibleOverlayLayout({
    required this.range,
    required this.left,
    required this.width,
  });

  final WaveformOverlayRange range;
  final double left;
  final double width;
}

class _OverlayRangeTile extends StatelessWidget {
  const _OverlayRangeTile({
    required this.range,
    required this.totalWidth,
    required this.windowStartMs,
    required this.actualWindowDurMs,
    required this.windowEndMs,
    required this.videoDurationMs,
    required this.onChanged,
    required this.isSelected,
    required this.onSelected,
    required this.showHandles,
  });

  final WaveformOverlayRange range;
  final double totalWidth;
  final int windowStartMs;
  final int actualWindowDurMs;
  final int windowEndMs;
  final int videoDurationMs;
  final ValueChanged<WaveformOverlayRange>? onChanged;
  final bool isSelected;
  final VoidCallback? onSelected;
  final bool showHandles;

  @override
  Widget build(BuildContext context) {
    final canInteract = onChanged != null || onSelected != null;
    final cs = Theme.of(context).colorScheme;
    final bodyColor = isSelected
        ? range.color.withValues(alpha: 0.24)
        : range.color.withValues(alpha: 0.16);
    final borderColor = isSelected
        ? range.color.withValues(alpha: 0.75)
        : range.color.withValues(alpha: 0.38);

    return IgnorePointer(
      ignoring: !canInteract,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onSelected,
              onTapDown: (_) => onSelected?.call(),
              onPanStart: (_) => onSelected?.call(),
              onPanUpdate: canInteract && !isSelected
                  ? (details) => _moveRange(details.delta.dx)
                  : null,
              child: Container(
                decoration: BoxDecoration(
                  color: bodyColor,
                  border: Border.all(
                    color: borderColor,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
            ),
          ),
          if (isSelected && showHandles)
            Positioned(
              left: 0,
              bottom: -2,
              height: 28,
              width: 24,
              child: _OverlayHandle(
                color: cs.primary,
                alignLeft: true,
                onPanUpdate: canInteract
                    ? (details) => _resizeRange(details.delta.dx, isStart: true)
                    : null,
              ),
            ),
          if (isSelected && showHandles)
            Positioned(
              right: 0,
              bottom: -2,
              height: 28,
              width: 24,
              child: _OverlayHandle(
                color: cs.primary,
                alignLeft: false,
                onPanUpdate: canInteract
                    ? (details) =>
                        _resizeRange(details.delta.dx, isStart: false)
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  void _moveRange(double deltaDx) {
    final changed = onChanged;
    if (changed == null) return;
    if (totalWidth <= 0 || actualWindowDurMs <= 0) return;
    final deltaMs = (deltaDx / totalWidth * actualWindowDurMs).round();
    if (deltaMs == 0) return;

    final durationMs = videoDurationMs;
    var start = range.startMs + deltaMs;
    var end = range.endMs + deltaMs;

    if (start < 0) {
      end -= start;
      start = 0;
    }
    if (end > durationMs) {
      final overflow = end - durationMs;
      start -= overflow;
      end = durationMs;
    }

    start = start.clamp(0, durationMs).toInt();
    end = end.clamp(0, durationMs).toInt();
    if (end <= start) {
      end = math.min(durationMs, start + 1);
    }

    changed(
      WaveformOverlayRange(
        segmentIndex: range.segmentIndex,
        startMs: start,
        endMs: end,
        color: range.color,
      ),
    );
  }

  void _resizeRange(double deltaDx, {required bool isStart}) {
    final changed = onChanged;
    if (changed == null) return;
    if (totalWidth <= 0 || actualWindowDurMs <= 0) return;
    final deltaMs = (deltaDx / totalWidth * actualWindowDurMs).round();
    if (deltaMs == 0) return;

    final durationMs = videoDurationMs;
    var start = range.startMs;
    var end = range.endMs;
    const minGapMs = 1;

    if (isStart) {
      start += deltaMs;
      start = start.clamp(0, math.max(0, end - minGapMs)).toInt();
    } else {
      end += deltaMs;
      end = end.clamp(start + minGapMs, durationMs).toInt();
    }

    if (start < 0) start = 0;
    if (end > durationMs) end = durationMs;
    if (end <= start) {
      if (isStart) {
        start = math.max(0, end - minGapMs);
      } else {
        end = math.min(durationMs, start + minGapMs);
      }
    }

    changed(
      WaveformOverlayRange(
        segmentIndex: range.segmentIndex,
        startMs: start,
        endMs: end,
        color: range.color,
      ),
    );
  }
}

class _OverlayHandle extends StatelessWidget {
  const _OverlayHandle({
    required this.color,
    required this.alignLeft,
    required this.onPanUpdate,
  });

  final Color color;
  final bool alignLeft;
  final GestureDragUpdateCallback? onPanUpdate;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 28,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: onPanUpdate,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: alignLeft ? Alignment.bottomLeft : Alignment.bottomRight,
          children: [
            Positioned(
              bottom: 18,
              left: alignLeft ? 10.5 : null,
              right: alignLeft ? null : 10.5,
              child: Container(
                width: 3,
                height: 7,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            Positioned(
              bottom: -1,
              left: alignLeft ? 4.5 : null,
              right: alignLeft ? null : 4.5,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.18),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WaveformOverlayRange {
  const WaveformOverlayRange({
    required this.segmentIndex,
    required this.startMs,
    required this.endMs,
    required this.color,
  });

  final int segmentIndex;
  final int startMs;
  final int endMs;
  final Color color;
}

/// 로딩 중 표시할 스켈레톤 파형.
class _LoadingSkeleton extends StatefulWidget {
  const _LoadingSkeleton({required this.height, required this.cs});
  final double height;
  final ColorScheme cs;

  @override
  State<_LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<_LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rng = math.Random(7);
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(40, (i) {
              final h = (rng.nextDouble() * 0.7 + 0.1) * widget.height;
              final alpha = 0.08 + _anim.value * 0.10;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Container(
                    height: h,
                    decoration: BoxDecoration(
                      color: widget.cs.onSurface.withValues(alpha: alpha),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
