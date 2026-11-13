// ============================================================================
// lib/features/_content/shorts/presentation/sections/shorts_page_control_section.dart
// ============================================================================
//
// [역할]
// 쇼츠 하단 컨트롤 섹션 (슬라이더).
// 드래그하여 영상 위치를 탐색하는 기능 제공.
//
// [레이어]
// Presentation Layer > Section
//
// ============================================================================

import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:video_player/video_player.dart';

/// [역할]
/// 비디오 재생 진행 상태 표시 및 탐색(Seeking) 기능을 담당하는 위젯.
///
/// [Slider]를 커스터마이징하여 제공하며, 드래그 시작/종료 시점을 상위 위젯에 알립니다.
/// 드래그 중에는 실제 재생 위치 대신 드래그 위치([_dragProgress])를 표시합니다.
class ShortsPageControlSection extends StatefulWidget {
  const ShortsPageControlSection({
    super.key,
    required this.controller,
    required this.durationMs,
    required this.onSeek,
    required this.onDragStart,
    required this.onDragEnd,
  });

  final VideoPlayerController? controller;
  final int durationMs;
  final Future<void> Function(double fraction) onSeek;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;

  @override
  State<ShortsPageControlSection> createState() =>
      _ShortsPageControlSectionState();
}

class _ShortsPageControlSectionState extends State<ShortsPageControlSection> {
  bool _isDragging = false;
  double? _dragProgress; // 0.0 ~ 1.0

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final pos = c?.value.position ?? Duration.zero;
    final dur = c?.value.duration ?? Duration(milliseconds: widget.durationMs);

    // 드래그 중에는 드래그 값 우선 사용
    final double liveProgress = dur.inMilliseconds == 0
        ? 0.0
        : (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);

    final double uiProgress = _isDragging && _dragProgress != null
        ? _dragProgress!.clamp(0.0, 1.0)
        : liveProgress;

    return GestureDetector(
      behavior: HitTestBehavior.opaque, // 터치 영역 확보
      onTap: () {}, // 부모 탭(재생/일시정지) 방지
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: SizedBox(
          height: 48,
          child: Center(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                thumbShape: SliderComponentShape.noThumb,
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                value: uiProgress.isNaN ? 0.0 : uiProgress,
                onChangeStart: (_) {
                  setState(() => _isDragging = true);
                  widget.onDragStart();
                },
                onChanged: (v) {
                  setState(() => _dragProgress = v);
                },
                onChangeEnd: (v) async {
                  await widget.onSeek(v);
                  if (!mounted) return;
                  setState(() {
                    _isDragging = false;
                    _dragProgress = null;
                  });
                  widget.onDragEnd();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
