// 영상 위 자막(플레이어·쇼츠)은 같은 그림자와 발음 색을 쓴다.
// 예전에는 쇼츠만 고쳐서, 플레이어의 발음 줄이 밝은 영상 위에서 묻혔다(5차).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/theme/video_subtitle_style.dart';
import 'package:parrokit/features/collection/clip/player/presentation/widgets/subtitle_overlay.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: Stack(children: [child]),
      ),
    );

TextStyle _styleOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;

void main() {
  testWidgets('세 줄 모두 두 겹 그림자를 쓰고 발음은 묻히지 않는다', (tester) async {
    await tester.pumpWidget(_wrap(const SubtitleOverlay(
      ja: 'Second test clip',
      pron: 'sekondeu',
      ko: '두 번째 클립',
    )));

    for (final line in ['Second test clip', 'sekondeu', '두 번째 클립']) {
      expect(_styleOf(tester, line).shadows, videoSubtitleShadows,
          reason: '$line: 밝은 영상 위에서도 테두리가 살아야 한다');
    }

    // 발음만 살짝 여리게. 예전 white70은 흰 바탕에 묻혔다.
    expect(_styleOf(tester, 'sekondeu').color, videoSubtitlePronColor);
    expect(_styleOf(tester, 'sekondeu').color, isNot(Colors.white70));
    expect(_styleOf(tester, 'Second test clip').color, Colors.white);
    expect(_styleOf(tester, '두 번째 클립').color, Colors.white);
  });

  testWidgets('발음이나 해석이 없으면 그 줄과 사이도 두지 않는다', (tester) async {
    await tester.pumpWidget(_wrap(const SubtitleOverlay(
      ja: 'Only original',
      pron: '',
      ko: '',
    )));

    expect(find.byType(Text), findsOneWidget);
    expect(find.byType(SizedBox), findsNothing,
        reason: '빈 줄 사이가 남으면 자막이 위로 떠 보인다');
  });
}
