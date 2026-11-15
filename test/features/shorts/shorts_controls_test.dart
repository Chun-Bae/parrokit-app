// 쇼츠 화면의 두 가지(5차 점검):
// - 오른쪽 버튼의 켜짐을 원 색으로만 보여, 화면 읽기로는 '자막'이 켜졌는지
//   알 수 없었다.
// - 아래 탐색 줄에 손잡이도 시각도 없어 끌 수 있는 줄인지, 어디로 가는지
//   알 수 없었다.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/collection/clip/shorts/presentation/sections/shorts_page_control_section.dart';
import 'package:parrokit/features/collection/clip/shorts/presentation/widgets/action_rail.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('켜고 끄는 버튼은 화면 읽기에 켜짐 여부를 알려 준다', (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(_wrap(ActionRail(
      autoNextEnabled: true,
      onAutoNextChanged: (_) {},
      onOpenExternalPlayer: () {},
      showSubtitle: false,
      onSubtitleChanged: (_) {},
    )));

    final autoNext = tester.getSemantics(find.bySemanticsLabel(RegExp('자동 넘김')));
    expect(autoNext.hasFlag(SemanticsFlag.hasToggledState), isTrue);
    expect(autoNext.hasFlag(SemanticsFlag.isToggled), isTrue);

    final subtitle = tester.getSemantics(find.bySemanticsLabel(RegExp('자막')));
    expect(subtitle.hasFlag(SemanticsFlag.hasToggledState), isTrue);
    expect(subtitle.hasFlag(SemanticsFlag.isToggled), isFalse,
        reason: '꺼져 있으면 꺼졌다고 읽어야 한다');

    // '연습'은 켜고 끄는 것이 아니라 플레이어를 여는 버튼이다.
    final practice = tester.getSemantics(find.bySemanticsLabel(RegExp('연습')));
    expect(practice.hasFlag(SemanticsFlag.hasToggledState), isFalse);

    handle.dispose();
  });

  testWidgets('탐색 줄은 끌 때만 시각을 보여 주고 끝나면 그 자리로 보낸다', (tester) async {
    double? seeked;
    var dragStarted = 0;
    var dragEnded = 0;

    await tester.pumpWidget(_wrap(SizedBox(
      width: 300,
      child: ShortsPageControlSection(
        controller: null,
        durationMs: 8000,
        onSeek: (fraction) async => seeked = fraction,
        onDragStart: () => dragStarted++,
        onDragEnd: () => dragEnded++,
      ),
    )));

    // 평소에는 시각이 보이지 않는다(투명).
    expect(find.text('0:00 / 0:08'), findsOneWidget);
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      0,
    );

    final slider = find.byType(Slider);
    final gesture = await tester.startGesture(tester.getCenter(slider));
    await tester.pump();
    await gesture.moveBy(const Offset(75, 0));
    await tester.pump();

    expect(dragStarted, 1);
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      1,
      reason: '끄는 동안에는 시각이 보인다',
    );
    // 손잡이도 끄는 동안에만 나온다.
    expect(
      SliderTheme.of(tester.element(slider)).thumbShape,
      isA<RoundSliderThumbShape>(),
    );
    // 300폭의 가운데에서 오른쪽으로 75만큼 끌면 4분의 3쯤이다.
    expect(find.text('0:06 / 0:08'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(dragEnded, 1);
    expect(seeked, isNotNull);
    expect(seeked!, closeTo(0.75, 0.1));
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      0,
      reason: '손을 떼면 다시 줄만 남는다',
    );
  });
}
