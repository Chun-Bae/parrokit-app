// 플레이어 알약 버튼은 꺼져 있어도 버튼으로 보여야 한다(5차).
//
// 꺼진 알약은 바탕이 화면색이고 테두리도 없어서, 흰 화면에서 '소리만 듣기'와
// 속도가 그냥 글자처럼 보였다. 켜진 것 셋만 버튼처럼 보이는 화면이었다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/collection/clip/player/presentation/widgets/speed_menu.dart';
import 'package:parrokit/features/collection/clip/player/presentation/widgets/toggle_pill.dart';

BoxDecoration _pillDecoration(WidgetTester tester, Finder pill) {
  final container = tester.widget<Container>(
    find.descendant(of: pill, matching: find.byType(Container)).first,
  );
  return container.decoration! as BoxDecoration;
}

void main() {
  testWidgets('켜진 알약과 꺼진 알약 모두 테두리가 있다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            TogglePill(
              key: const ValueKey('on'),
              icon: Icons.repeat_rounded,
              label: '반복',
              active: true,
              onTap: () {},
            ),
            TogglePill(
              key: const ValueKey('off'),
              icon: Icons.headphones_rounded,
              label: '소리만 듣기',
              active: false,
              onTap: () {},
            ),
          ],
        ),
      ),
    ));

    final on = _pillDecoration(tester, find.byKey(const ValueKey('on')));
    final off = _pillDecoration(tester, find.byKey(const ValueKey('off')));
    expect(on.border, isNotNull);
    expect(off.border, isNotNull, reason: '꺼진 알약도 버튼으로 보여야 한다');
    // 켜진 것과 꺼진 것은 여전히 구분된다.
    expect(on.color, isNot(off.color));
  });

  testWidgets('속도 버튼도 같은 테두리를 쓴다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SpeedMenu(value: 1.0, onSelected: (_) {}),
      ),
    ));

    final decoration = _pillDecoration(tester, find.byType(SpeedMenu));
    expect(decoration.border, isNotNull);
  });
}
