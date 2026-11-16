// n단 머리줄 모듈(5차 332). 커뮤니티 앱바가 하던 움직임을 그대로 따른다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/widgets/tiered_header.dart';

TieredHeaderDelegate communityLike() => TieredHeaderDelegate(tiers: const [
      HeaderTier(height: 56, child: SizedBox()), // 제목
      HeaderTier(height: 48, child: SizedBox(), sticky: true), // 탭
      HeaderTier(height: 68, child: SizedBox()), // 필터
    ]);

void main() {
  test('높이는 단을 모두 더한 값이다', () {
    expect(communityLike().maxExtent, 56 + 48 + 68);
    expect(communityLike().minExtent, 0);
  });

  test('붙지 않은 단은 접는 만큼 그대로 올라간다', () {
    final d = communityLike();
    expect(d.topOf(0, 0), 56 - 56); // 제목은 0에서 시작
    expect(d.topOf(0, 20), -20);
    expect(d.topOf(2, 0), 104); // 필터는 56+48 아래
    expect(d.topOf(2, 30), 74);
  });

  test('붙는 단은 맨 위에서 버티다가 마지막에 올라간다', () {
    final d = communityLike();
    expect(d.topOf(1, 0), 56);
    expect(d.topOf(1, 56), 0, reason: '제목이 다 접히면 맨 위에 붙는다');
    expect(d.topOf(1, 100), 0, reason: '아래 필터가 접히는 동안 버틴다');
    expect(d.topOf(1, 124), 0, reason: '56+68까지는 버틴다');
    expect(d.topOf(1, 150), 124 - 150);
  });

  test('붙는 단을 나중에 그려 위에 올린다', () {
    // 그리는 차례: 필터(2) → 제목(0) → 탭(1). 커뮤니티 앱바와 같다.
    expect(communityLike().paintOrder(), [2, 0, 1]);
  });

  test('단이 하나뿐이어도 된다', () {
    final one = TieredHeaderDelegate(
        tiers: const [HeaderTier(height: 56, child: SizedBox())]);
    expect(one.maxExtent, 56);
    expect(one.paintOrder(), [0]);
    expect(one.topOf(0, 10), -10);
  });

  testWidgets('스크롤하면 머리줄이 접히고 붙는 단은 남는다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TieredHeaderScroll(
          tiers: const [
            HeaderTier(height: 56, child: Text('제목')),
            HeaderTier(height: 48, child: Text('탭'), sticky: true),
          ],
          body: ListView.builder(
            itemCount: 40,
            itemBuilder: (_, i) => SizedBox(height: 60, child: Text('줄 $i')),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('제목'), findsOneWidget);
    expect(find.text('탭'), findsOneWidget);

    await tester.fling(find.text('줄 1'), const Offset(0, -400), 1000);
    await tester.pumpAndSettle();
    // 다 접히면 머리줄은 사라진다(커뮤니티 앱바와 같다. floating + minExtent 0).
    expect(find.text('제목'), findsNothing);
    expect(find.text('탭'), findsNothing);

    // 위로 조금만 끌어도 머리줄이 다시 내려온다.
    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();
    expect(find.text('탭'), findsOneWidget);
  });
}
