import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/content-studio/captioning/presentation/providers/mixins/edit_segment_mixin.dart';
import 'package:parrokit/features/content-studio/captioning/presentation/widgets/time_triplet_field.dart';

List<String> _fieldTexts(WidgetTester tester) => tester
    .widgetList<TextField>(find.byType(TextField))
    .map((f) => f.controller!.text)
    .toList();

void main() {
  testWidgets('시각 칸은 자리를 채워 보여서 0.05초가 0.5초로 읽히지 않는다',
      (tester) async {
    final target = TextEditingController(text: '00:00.050');
    addTearDown(target.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TimeTripletField(label: 'B', target: target, showGuide: false),
      ),
    ));
    expect(_fieldTexts(tester), ['00', '00', '050']);

    // 밖에서 값이 바뀌어도(재생 위치로 B 찍기 등) 자리를 채운다.
    target.text = '01:05.007';
    await tester.pump();
    expect(_fieldTexts(tester), ['01', '05', '007']);
  });

  testWidgets('치고 있는 칸은 자리 채우기로 덮어쓰지 않는다', (tester) async {
    final target = TextEditingController(text: '00:00.000');
    addTearDown(target.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TimeTripletField(label: 'B', target: target, showGuide: false),
      ),
    ));
    final seconds = find.byType(TextField).at(1);
    await tester.tap(seconds);
    await tester.pump();
    // 누르면 '00' 전체가 골라져서 치는 숫자로 바뀐다.
    final ctl = tester.widget<TextField>(seconds).controller!;
    expect(ctl.selection, const TextSelection(baseOffset: 0, extentOffset: 2));
    await tester.enterText(seconds, '5');
    await tester.pump();
    expect(target.text, '00:05.000');
    expect(_fieldTexts(tester)[1], '5');
  });

  test('자동 보정 안내는 고친 이유를 말한다', () {
    expect(
        EditSegmentMixin.adjustReasonFor(1000, 500, 0, 6000,
            upperIsVideoEnd: true),
        contains('B는 A보다 뒤여야'));
    expect(
        EditSegmentMixin.adjustReasonFor(1000, 9000, 0, 6000,
            upperIsVideoEnd: true),
        contains('영상 길이'));
    expect(
        EditSegmentMixin.adjustReasonFor(1000, 3000, 0, 2000,
            upperIsVideoEnd: false),
        contains('겹치지 않게'));
    expect(
        EditSegmentMixin.adjustReasonFor(100, 3000, 500, 6000,
            upperIsVideoEnd: true),
        contains('겹치지 않게'));
  });
}
