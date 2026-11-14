import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parrokit/features/collection/shared/storage_segment_bar.dart';

void main() {
  group('storageSegmentFlex', () {
    test('아주 작은 칸도 보이게 최소 몫을 준다', () {
      // Drive 123GB 안의 Parrokit 91KB. 비율대로면 한 픽셀도 안 된다.
      const other = 123 * 1024 * 1024 * 1024;
      const parrokit = 91 * 1024;
      final flex = storageSegmentFlex([other, parrokit]);

      expect(flex[1], greaterThanOrEqualTo(storageSegmentMinShare));
      expect(flex[0], greaterThan(flex[1]));
      expect(flex[0] + flex[1], storageSegmentResolution);
    });

    test('값이 0인 칸은 그리지 않는다', () {
      final flex = storageSegmentFlex([100, 0, 100]);
      expect(flex[1], 0);
      expect(flex[0], flex[2]);
    });

    test('넉넉한 값은 비율 그대로 나눈다', () {
      final flex = storageSegmentFlex([300, 100]);
      expect(flex[0], 750);
      expect(flex[1], 250);
    });

    test('모두 0이면 아무 칸도 없다', () {
      expect(storageSegmentFlex([0, 0]), [0, 0]);
    });
  });

  testWidgets('아주 작은 칸도 막대에 실제로 그려진다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          child: StorageSegmentBar(segments: const [
            StorageSegment(value: 123 * 1024 * 1024 * 1024, color: Colors.grey),
            StorageSegment(value: 91 * 1024, color: Colors.blue),
          ]),
        ),
      ),
    ));
    await tester.pump();

    // 너비뿐 아니라 실제로 칠해지는 높이까지 본다. 자식 없는 ColoredBox를
    // 썼을 때 높이가 0이 돼 화면에서 막대가 통째로 사라진 적이 있다(5차).
    final blue = find.byWidgetPredicate(
        (w) => w is Container && w.color == Colors.blue);
    final size = tester.getSize(blue);
    expect(size.width, greaterThanOrEqualTo(4));
    expect(size.height, storageSegmentBarHeight);
  });

  testWidgets('값이 모두 0이어도 빈 막대를 그린다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          child: StorageSegmentBar(segments: const [
            StorageSegment(value: 0, color: Colors.grey),
          ]),
        ),
      ),
    ));
    await tester.pump();
    expect(find.byType(Expanded), findsNothing);
    final bar = find.descendant(
        of: find.byType(StorageSegmentBar), matching: find.byType(Container));
    expect(tester.getSize(bar.first).height, storageSegmentBarHeight);
  });
}
