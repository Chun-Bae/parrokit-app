import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/collection/clip/shorts/presentation/widgets/action_rail.dart';

void main() {
  testWidgets('쇼츠 오른쪽 버튼은 한국어 글자로 보이고 누르면 각 동작을 부른다',
      (tester) async {
    bool? autoNext;
    bool? subtitle;
    var opened = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: ActionRail(
            autoNextEnabled: false,
            onAutoNextChanged: (v) => autoNext = v,
            onOpenExternalPlayer: () => opened++,
            showSubtitle: true,
            onSubtitleChanged: (v) => subtitle = v,
          ),
        ),
      ),
    ));

    expect(find.text('Auto'), findsNothing);
    expect(find.text('CC'), findsNothing);
    expect(find.text('Player'), findsNothing);

    await tester.tap(find.text('자동 넘김'));
    await tester.tap(find.text('자막'));
    await tester.tap(find.text('연습'));
    expect(autoNext, isTrue);
    expect(subtitle, isFalse);
    expect(opened, 1);
    expect(tester.takeException(), isNull);
  });
}
