import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/sentence_transfer.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/sentence_import_sheet.dart';

const items = [
  ImportedSentence(text: 'One', translation: '하나', language: '영어'),
  ImportedSentence(text: 'Two', translation: '둘'),
  ImportedSentence(text: 'Three', translation: '셋', language: '일본어'),
];

Future<void> openSheet(
  WidgetTester tester, {
  required Future<String?> Function(ImportedSentence) addOne,
  required Future<void> Function(String) removeOne,
  required void Function(SentenceImportResult?) onResult,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async => onResult(await showSentenceImportSheet(
            context,
            items: items,
            defaultLanguage: '영어',
            existingKeys: const {},
            addOne: addOne,
            removeOne: removeOne,
          )),
          child: const Text('열기'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('외국어는 문장 오른쪽 칩으로 보인다', (tester) async {
    await openSheet(
      tester,
      addOne: (_) async => 'id',
      removeOne: (_) async {},
      onResult: (_) {},
    );
    final chips = find.byKey(const ValueKey('import-language-chip'));
    expect(chips, findsNWidgets(3));
    expect(find.descendant(of: chips.at(0), matching: find.text('영어')),
        findsOneWidget);
    // 언어가 없는 문장은 화면에서 고른 언어(영어)를 쓴다.
    expect(find.descendant(of: chips.at(1), matching: find.text('영어')),
        findsOneWidget);
    expect(find.descendant(of: chips.at(2), matching: find.text('일본어')),
        findsOneWidget);
    // 칩은 문장보다 오른쪽에 있다.
    expect(tester.getTopLeft(chips.at(0)).dx,
        greaterThan(tester.getTopLeft(find.text('One')).dx));
  });

  testWidgets('옮기는 도중 취소하면 멈추고 여기까지 가져온 문장만 보여준 뒤 선택하게 한다', (tester) async {
    final gates = [for (var i = 0; i < 3; i++) Completer<String?>()];
    final started = <String>[];
    final removed = <String>[];
    SentenceImportResult? result;
    var finished = false;
    await openSheet(
      tester,
      addOne: (item) {
        started.add(item.text);
        return gates[started.length - 1].future;
      },
      removeOne: (id) async => removed.add(id),
      onResult: (value) {
        result = value;
        finished = true;
      },
    );
    await tester.tap(find.byKey(const ValueKey('import-start')));
    await tester.pump();
    // 첫 문장은 옮겨졌고 두 번째를 옮기는 중에 취소를 누른다.
    gates[0].complete('a');
    await tester.pump();
    await tester.pump();
    expect(started, ['One', 'Two']);
    await tester.tap(find.byKey(const ValueKey('import-running-cancel')));
    await tester.pump();
    expect(find.textContaining('멈추는 중'), findsOneWidget);

    gates[1].complete('b');
    await tester.pumpAndSettle();

    // 세 번째는 시작하지 않았고 시트는 그대로 열려 있다. 아직 아무것도 지우지 않았다.
    expect(started, ['One', 'Two']);
    expect(removed, isEmpty);
    expect(finished, isFalse);
    expect(find.text('여기까지 옮겼어요'), findsOneWidget);
    expect(find.textContaining('여기까지 2개를 가져왔어요'), findsOneWidget);
    expect(find.textContaining('나머지 1개는 가져오지 않았어요'), findsOneWidget);
    // 옮긴 두 문장만 목록에 남는다.
    expect(find.text('One'), findsOneWidget);
    expect(find.text('Two'), findsOneWidget);
    expect(find.text('Three'), findsNothing);

    // 여기서 취소하면 여기까지 가져온 문장을 되돌리고, 닫지 않고 고르는 목록으로 돌아간다.
    await tester.tap(find.byKey(const ValueKey('import-undo')));
    await tester.pumpAndSettle();
    expect(removed, ['a', 'b']);
    expect(finished, isFalse);
    expect(find.byKey(const ValueKey('import-sheet')), findsOneWidget);
    expect(find.text('가져올 문장 3개'), findsOneWidget);
    expect(find.text('3개 가져오기'), findsOneWidget);
    expect(find.text('Three'), findsOneWidget);

    // 고른 상태가 그대로라서 잘못 고른 문장만 빼고 다시 가져올 수 있다.
    await tester.tap(find.byKey(const ValueKey('import-item-0')));
    await tester.pump();
    expect(find.text('2개 가져오기'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('import-cancel')));
    await tester.pumpAndSettle();
    expect(finished, isTrue);
    expect(result, isNull);
  });

  testWidgets('도중에 멈춘 뒤 완료하면 여기까지 가져온 문장을 남긴다', (tester) async {
    final gates = [for (var i = 0; i < 3; i++) Completer<String?>()];
    var count = 0;
    final removed = <String>[];
    SentenceImportResult? result;
    await openSheet(
      tester,
      addOne: (item) => gates[count++].future,
      removeOne: (id) async => removed.add(id),
      onResult: (value) => result = value,
    );
    await tester.tap(find.byKey(const ValueKey('import-start')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('import-running-cancel')));
    await tester.pump();
    gates[0].complete('a');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('import-done')));
    await tester.pumpAndSettle();
    expect(removed, isEmpty);
    expect(result?.added, 1);
  });
}
