// 글 상세의 공감·스크랩 버튼(5차). 공감은 수를 버튼에 함께 보인다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/community/board/presentation/widgets/board_action_tile.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('수를 주면 글자 옆에 함께 보인다', (tester) async {
    await tester.pumpWidget(_wrap(BoardActionTile(
      icon: Icons.thumb_up_outlined,
      label: '공감',
      count: 4,
      selected: false,
      accentColor: Colors.blue,
      onTap: () {},
    )));
    expect(find.text('공감 4'), findsOneWidget);
    expect(find.text('공감'), findsNothing);
  });

  testWidgets('수가 없으면 글자만 보인다(스크랩)', (tester) async {
    await tester.pumpWidget(_wrap(BoardActionTile(
      icon: Icons.bookmark_outline,
      label: '스크랩',
      selected: false,
      accentColor: Colors.blue,
      onTap: () {},
    )));
    expect(find.text('스크랩'), findsOneWidget);
  });

  testWidgets('0이어도 수를 보인다', (tester) async {
    await tester.pumpWidget(_wrap(BoardActionTile(
      icon: Icons.thumb_up_outlined,
      label: '공감',
      count: 0,
      selected: false,
      accentColor: Colors.blue,
      onTap: () {},
    )));
    expect(find.text('공감 0'), findsOneWidget);
  });

  testWidgets('누르면 알려 준다', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_wrap(BoardActionTile(
      icon: Icons.thumb_up_outlined,
      label: '공감',
      count: 1,
      selected: true,
      accentColor: Colors.blue,
      onTap: () => taps++,
    )));
    await tester.tap(find.text('공감 1'));
    expect(taps, 1);
  });
}
