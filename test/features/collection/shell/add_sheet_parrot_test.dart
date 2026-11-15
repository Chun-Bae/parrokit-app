// 보관함 '무엇을 추가할까요?' 시트: 패롯이 드는 줄을 알린다(5차).
//
// 문장·클립·단어 추가는 그냥 저장이고, 음성·영상 만들기는 패롯이 든다.
// 한 목록에 섞여 있어서 누르기 전에 알 수 있어야 한다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/collection/shell/presentation/collection_shell_screen.dart';

void main() {
  testWidgets('패롯이 드는 줄에만 표시가 붙는다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          addMaterialTileForTest(
            icon: Icons.format_quote_rounded,
            title: '문장 추가',
            subtitle: '원문과 뜻을 직접 적어요',
            onTap: () {},
          ),
          addMaterialTileForTest(
            icon: Icons.graphic_eq_rounded,
            title: '음성 만들기',
            subtitle: '문장을 읽어 주는 음성을 만들어요',
            onTap: () {},
            usesParrots: true,
          ),
        ]),
      ),
    ));

    expect(find.text(addSheetUsesParrotsLabel), findsOneWidget);
    // 표시가 붙은 쪽은 '음성 만들기'다.
    final badge = find.text(addSheetUsesParrotsLabel);
    final row = find.ancestor(of: badge, matching: find.byType(ListTile));
    expect(
      find.descendant(of: row, matching: find.text('음성 만들기')),
      findsOneWidget,
    );
  });

  testWidgets('그냥 저장하는 줄에는 표시가 없다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: addMaterialTileForTest(
          icon: Icons.spellcheck_rounded,
          title: '단어 추가',
          subtitle: '단어와 뜻을 저장하고 복습해요',
          onTap: () {},
        ),
      ),
    ));

    expect(find.text(addSheetUsesParrotsLabel), findsNothing);
  });
}
