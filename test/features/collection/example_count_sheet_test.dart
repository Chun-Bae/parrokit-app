// 예문 개수를 고르는 시트(5차 546).
//
// 낱말당 상한은 어디나 10인데(examplesMaxCount, 서버 MAX_WORD_EXAMPLES,
// 플러스·프로·맥스의 examplesPerWord) 이 시트만 5로 잘라 두었다. 같은
// 시트가 '10개까지 둘 수 있어요'라고 적어 놓고 5까지만 내주었다.

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/my_word_store.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/example_count_sheet.dart';

Future<void> openSheet(
  WidgetTester tester, {
  required int room,
  int already = 0,
  int? maxPerWord,
  int? remainingToday,
  int? exampleCredits,
}) async {
  await tester.pumpWidget(CupertinoApp(
    home: Builder(
      builder: (context) => CupertinoButton(
        onPressed: () => askExampleCount(
          context,
          room: room,
          already: already,
          maxPerWord: maxPerWord,
          remainingToday: remainingToday,
          exampleCredits: exampleCredits,
        ),
        child: const Text('열기'),
      ),
    ),
  ));
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('자리가 넉넉하면 상한까지 고를 수 있다', (tester) async {
    await openSheet(tester,
        room: examplesMaxCount, maxPerWord: 10, remainingToday: 200);

    for (var n = 1; n <= examplesMaxCount; n++) {
      expect(find.byKey(ValueKey('example-count-$n')), findsOneWidget,
          reason: '$n개를 고를 수 없다');
    }
  });

  testWidgets('적어 둔 상한보다 많이 내주지 않는다', (tester) async {
    // 무료는 낱말당 3개다. 말과 고를 수 있는 수가 어긋나면 안 된다.
    await openSheet(tester, room: 3, maxPerWord: 3, remainingToday: 10);

    expect(find.byKey(const ValueKey('example-count-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('example-count-4')), findsNothing);
  });

  testWidgets('오늘 남은 수가 적으면 거기에 맞춘다', (tester) async {
    await openSheet(tester, room: 10, maxPerWord: 10, remainingToday: 2);

    expect(find.byKey(const ValueKey('example-count-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('example-count-3')), findsNothing);
  });

  test('남은 수 줄은 하루치와 사 둔 몫을 나눠 적는다', () {
    expect(exampleRoomLine(12, 10), ' 오늘 2개와 사 둔 10개를 쓸 수 있어요.');
    expect(exampleRoomLine(10, 10), ' 사 둔 10개를 쓸 수 있어요.');
    expect(exampleRoomLine(4, 0), ' 오늘 4개 더 만들 수 있어요.');
    expect(exampleRoomLine(null, 3), '');
  });
}
