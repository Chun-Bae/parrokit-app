// 구간 재생일 때 시계와 구간 칩이 같은 잣대를 쓰는지(5차).
//
// 8초짜리 영상 안의 1.2초 구간을 돌리면 칩은 '0:01.2 – 0:02.4'인데 시계는
// '0:01 / 0:08'이었다. 한 화면에서 두 잣대가 엇갈렸고, 구간을 도는 내내
// 시계는 '0:01'과 '0:02' 둘만 오갔다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/collection/clip/player/presentation/engine/clip_player_engine.dart';
import 'package:parrokit/features/collection/clip/player/presentation/widgets/segment_timeline.dart';

class _FakeEngine extends ChangeNotifier implements ClipPlayerEngine {
  _FakeEngine({required this.position, required this.duration});

  @override
  final Duration position;

  @override
  final Duration duration;

  @override
  bool get isReady => true;

  @override
  bool get isPlaying => true;

  @override
  bool get keepsPlayingInBackground => true;

  @override
  bool get handlesClipRange => true;

  @override
  double get aspectRatio => 9 / 16;

  @override
  Size get size => const Size(720, 1280);

  @override
  String get title => '';

  @override
  Future<void> open(String absolutePath,
          {double speed = 1.0, String title = ''}) async =>
      {};

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> seekTo(Duration position) async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> setLooping(bool value) async {}

  @override
  Future<void> setRange({
    Duration? clipBegin,
    Duration? clipEnd,
    bool loop = false,
  }) async {}

  @override
  Future<void> close() async {}

  @override
  Widget surface() => const SizedBox.shrink();

  @override
  Future<void> dispose() async => super.dispose();
}

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required Duration position,
    required Duration duration,
    required Duration start,
    required Duration end,
    required bool segmentScope,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SegmentTimeline(
          engine: _FakeEngine(position: position, duration: duration),
          start: start,
          end: end,
          segmentScope: segmentScope,
          onSeek: (_) {},
        ),
      ),
    ));
    // 채움 막대의 TweenAnimationBuilder가 끝나기를 기다린다.
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('구간 재생이면 짧은 구간에서 시계가 0.1초까지 보인다', (tester) async {
    await pump(
      tester,
      position: const Duration(milliseconds: 1500),
      duration: const Duration(seconds: 8),
      start: const Duration(milliseconds: 1200),
      end: const Duration(milliseconds: 2400),
      segmentScope: true,
    );

    expect(find.text('0:01.5'), findsOneWidget);
    expect(find.text('0:08.0'), findsOneWidget);
    // 예전에는 구간을 도는 내내 '0:01'에서 멈춰 보였다.
    expect(find.text('0:01'), findsNothing);
  });

  testWidgets('전체 재생이면 예전처럼 초만 보인다', (tester) async {
    await pump(
      tester,
      position: const Duration(milliseconds: 1500),
      duration: const Duration(seconds: 8),
      start: const Duration(milliseconds: 1200),
      end: const Duration(milliseconds: 2400),
      segmentScope: false,
    );

    expect(find.text('0:01'), findsOneWidget);
    expect(find.text('0:08'), findsOneWidget);
  });

  testWidgets('구간이 2초 이상이면 구간 재생이어도 초만 보인다', (tester) async {
    await pump(
      tester,
      position: const Duration(milliseconds: 2500),
      duration: const Duration(seconds: 8),
      start: const Duration(milliseconds: 1000),
      end: const Duration(milliseconds: 4000),
      segmentScope: true,
    );

    expect(find.text('0:02'), findsOneWidget);
    expect(find.text('0:08'), findsOneWidget);
  });
}
