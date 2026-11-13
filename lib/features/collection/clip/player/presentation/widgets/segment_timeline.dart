import '../clip_time_format.dart';
import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:video_player/video_player.dart';
import 'seek_gesture_layer.dart';

class SegmentTimeline extends StatelessWidget {
  const SegmentTimeline({
    super.key,
    required this.controller,
    required this.start, // ⬅️ 호출부 호환용 (미사용)
    required this.end, // ⬅️ 호출부 호환용 (미사용)
    required this.onSeek,
  });

  final VideoPlayerController controller;
  final Duration start; // 미사용
  final Duration end; // 미사용
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context) {
    final pos = controller.value.position;
    final total = controller.value.duration;

    double frac(double v, double max) =>
        (max <= 0 ? 0.0 : (v / max).clamp(0.0, 1.0));

    final posFrac =
        frac(pos.inMilliseconds.toDouble(), total.inMilliseconds.toDouble());

    final cs = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    final track = isLight
        ? cs.outlineVariant.withValues(alpha: 0.5)
        : Colors.white10; // 회색 트랙
    final prog = isLight ? cs.inversePrimary : Colors.white; // 채워지는 진행색

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        children: [
          SizedBox(
            height: 22,
            child: LayoutBuilder(
              builder: (context, c) {
                return Stack(
                  children: [
                    // 전체 회색 트랙
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: track,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                      ),
                    ),
                    // 진행 채움 (왼쪽부터 현재 위치까지)
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(end: posFrac),
                          duration:
                              const Duration(milliseconds: 100), // 부드러움 정도
                          builder: (context, animatedFrac, _) {
                            return FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: animatedFrac.clamp(0.0, 1.0),
                              child: RepaintBoundary(
                                // 불필요한 리페인트 줄이기(선택)
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: prog,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.full),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // 제스처(탭/드래그)로 전체 길이 기준 시킹
                    Positioned.fill(
                      child: SeekGestureLayer(
                        onSeek: (dx, width) {
                          final f = (dx / width).clamp(0.0, 1.0);
                          onSeek(Duration(
                            milliseconds: (total.inMilliseconds * f).round(),
                          ));
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // 라벨: 현재 위치 / 전체 길이 (중앙 세그먼트 표시는 제거)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _timeLabel(controller.value.position, isLight),
              _timeLabel(controller.value.duration, isLight),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeLabel(Duration d, bool isLight) {
    return Builder(
      builder: (context) => Text(
        _fmt(d),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isLight ? Colors.black54 : Colors.white70,
            ),
      ),
    );
  }

  String _fmt(Duration d) => clipClock(d.inMilliseconds);
}
