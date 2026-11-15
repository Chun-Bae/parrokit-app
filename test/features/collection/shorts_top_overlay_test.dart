// 쇼츠 위쪽 줄이 클립 이름을 보여 주는지, 탭을 가로채지 않는지 확인한다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/features/collection/clip/shorts/presentation/widgets/shorts_top_overlay.dart';

Widget _wrap(Widget child) {
  final cs = ColorScheme.fromSeed(seedColor: Colors.green);
  return MaterialApp(
    theme: ThemeData(
      colorScheme: cs,
      textTheme: appTextTheme(cs, isDark: false),
    ),
    home: Scaffold(body: Stack(children: [child])),
  );
}

void main() {
  testWidgets('클립 이름과 태그를 보여 준다', (tester) async {
    await tester.pumpWidget(_wrap(const ShortsTopOverlay(
      index: 0,
      total: 3,
      title: '오사카 역 안내',
      tagNames: ['여행', '일본어'],
    )));

    expect(find.text('오사카 역 안내'), findsOneWidget);
    expect(find.text('여행'), findsOneWidget);
    expect(find.text('일본어'), findsOneWidget);
  });

  testWidgets('이름이 비었으면 줄을 그리지 않는다', (tester) async {
    await tester.pumpWidget(_wrap(const ShortsTopOverlay(
      index: 0,
      total: 2,
      title: '   ',
      tagNames: [],
    )));

    expect(find.byType(Text), findsNothing);
  });

  testWidgets('긴 이름은 한 줄로 줄인다', (tester) async {
    await tester.pumpWidget(_wrap(ShortsTopOverlay(
      index: 1,
      total: 4,
      title: '아주 긴 클립 이름' * 10,
      tagNames: const [],
    )));

    final text = tester.widget<Text>(find.byType(Text));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
  });

  testWidgets('이름 글자는 흰색이고 그림자가 있다', (tester) async {
    await tester.pumpWidget(_wrap(const ShortsTopOverlay(
      index: 0,
      total: 2,
      title: '컬러바',
      tagNames: [],
    )));

    final style = tester.widget<Text>(find.text('컬러바')).style!;
    expect(style.color, Colors.white);
    expect(style.shadows, isNotEmpty);
  });

  testWidgets('영상 탭(멈춤)을 가로채지 않는다', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_wrap(
      Stack(children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => taps++,
          child: const SizedBox.expand(),
        ),
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ShortsTopOverlay(
            index: 0,
            total: 2,
            title: '컬러바',
            tagNames: ['여행'],
          ),
        ),
      ]),
    ));

    await tester.tap(find.text('여행'), warnIfMissed: false);
    await tester.pump();
    expect(taps, 1, reason: '배지 위를 눌러도 영상 멈춤이 동작해야 한다');
  });
}
