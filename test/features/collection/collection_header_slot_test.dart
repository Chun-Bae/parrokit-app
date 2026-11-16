// 탭 안쪽 줄을 보관함 머리줄로 올려 두는 자리(5차 336, 사용자 요청).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/collection_header_slot.dart';

void main() {
  test('높이가 바뀔 때만 바깥 화면을 다시 그린다', () {
    var calls = 0;
    final slot = CollectionHeaderSlot(onHeightsChanged: () => calls++);

    slot.put(heights: const [54], build: (_) => const SizedBox());
    expect(calls, 1, reason: '없던 단이 생겼으니 다시 재야 한다');

    // 내용만 바뀐 경우(칩을 골랐을 때). 높이는 그대로다.
    slot.put(heights: const [54], build: (_) => const Text('고름'));
    expect(calls, 1);
    expect(slot.revision.value, 2, reason: '그 단만 다시 그린다');

    slot.put(heights: const [54, 158], build: (_) => const SizedBox());
    expect(calls, 2);

    slot.clear();
    expect(calls, 3);
    expect(slot.isEmpty, isTrue);

    slot.clear();
    expect(calls, 3, reason: '이미 비었으면 다시 그리지 않는다');
    slot.dispose();
  });

  testWidgets('내용이 바뀌면 그 단만 새로 그린다', (tester) async {
    final slot = CollectionHeaderSlot(onHeightsChanged: () {});
    slot.put(heights: const [54], build: (_) => const Text('처음'));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Column(children: [slot.tiers().single.child])),
    ));
    expect(find.text('처음'), findsOneWidget);

    // 바깥 화면을 다시 그리지 않고 안쪽 화면이 새 줄을 올려 둔 경우.
    slot.put(heights: const [54], build: (_) => const Text('바뀜'));
    await tester.pump();
    expect(find.text('바뀜'), findsOneWidget);
    expect(find.text('처음'), findsNothing);
    slot.dispose();
  });

  test('올려 둔 단의 높이를 그대로 쓴다', () {
    final slot = CollectionHeaderSlot(onHeightsChanged: () {});
    slot.put(heights: const [54, 158], build: (_) => const SizedBox());
    expect(slot.tiers().map((t) => t.height), [54, 158]);
    slot.dispose();
  });
}
