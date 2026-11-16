// 유의어는 쉼표가 아니라 '추가'로 넣는다(5차, 사용자 요청).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/my_word_store.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/word_collection_preview.dart';

void main() {
  var current = <String>[];

  Future<void> pump(WidgetTester tester) async {
    current = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => SynonymEditor(
            synonyms: current,
            onChanged: (next) => setState(() => current = next),
          ),
        ),
      ),
    ));
  }

  Future<void> add(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const ValueKey('word-synonyms')), text);
    await tester.tap(find.byKey(const ValueKey('add-synonym')));
    await tester.pump();
  }

  testWidgets('추가를 누르면 칩으로 쌓이고, ×로 뺀다', (tester) async {
    await pump(tester);

    await add(tester, 'big');
    await add(tester, 'large');
    expect(current, ['big', 'large']);
    expect(find.byKey(const ValueKey('synonym-chip-big')), findsOneWidget);

    await tester.tap(find.byTooltip('big 빼기'));
    await tester.pumpAndSettle();
    expect(current, ['large']);
  });

  testWidgets('붙여넣은 쉼표 글은 한 번에 나눠 넣는다', (tester) async {
    await pump(tester);

    await add(tester, 'big, large');
    expect(current, ['big', 'large']);
  });

  testWidgets('같은 것을 또 넣으면 까닭을 적는다', (tester) async {
    await pump(tester);

    await add(tester, 'big');
    await add(tester, 'big');
    expect(current, ['big']);
    expect(find.byKey(const ValueKey('synonym-hint')), findsOneWidget);
    expect(find.text('이미 넣은 유의어예요.'), findsOneWidget);
  });

  testWidgets('빈 칸으로 누르면 적으라고 한다', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('add-synonym')));
    await tester.pump();
    expect(find.text('넣을 유의어를 적어 주세요.'), findsOneWidget);
  });

  testWidgets('한도까지 차면 더 넣지 않고 까닭을 적는다', (tester) async {
    await pump(tester);

    for (var i = 0; i < synonymsMaxCount; i++) {
      await add(tester, 'w$i');
    }
    expect(current.length, synonymsMaxCount);

    await add(tester, 'one more');
    expect(current.length, synonymsMaxCount);
    expect(find.text('유의어는 $synonymsMaxCount개까지 넣을 수 있어요.'), findsOneWidget);
  });
}
