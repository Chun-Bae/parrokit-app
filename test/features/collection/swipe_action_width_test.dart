// 밀어서 여는 칸 너비(5차). 목록마다 제각각이면 어떤 줄을 다루는지 가려진다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/collection/library/presentation/widgets/swipe_action_tile.dart';

void main() {
  test('한 칸 너비는 손가락으로 누를 만하고 화면을 다 덮지 않는다', () {
    expect(swipeActionSlotWidth, 84);
    // 세 칸(편집·옮기기·삭제)을 열어도 440pt 화면의 절반을 조금 넘는다.
    expect(swipeActionSlotWidth * 3, lessThan(440 * 0.6));
  });

  testWidgets('연 만큼만 줄이 밀리고 칸이 그 너비로 그려진다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SwipeActionTile(
          actionWidth: swipeActionSlotWidth * 2,
          actions: const [
            SizedBox(key: ValueKey('a1')),
            SizedBox(key: ValueKey('a2')),
          ],
          child: const SizedBox(height: 64, child: Text('클립 제목')),
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('클립 제목'), findsOneWidget);
  });
}
