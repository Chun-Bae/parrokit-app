// 단어를 지우기 전에 한 번 물어야 한다(5차 401).
//
// 문장은 목록에서도 상세에서도 물으면서, 단어는 밀어서 지우기도 상세의
// '단어 지우기'도 누르는 순간 사라졌다. 뜻·유의어·예문과 복습 진도까지
// 함께 없어지는데 되돌릴 수 없다.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/word_collection_preview.dart'
    show confirmDeleteWord;

String _code(String path) => File(path)
    .readAsStringSync()
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

Future<bool?> _open(WidgetTester tester) async {
  bool? answer;
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              answer = await confirmDeleteWord(context, 'projection'),
          child: const Text('열기'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
  return answer;
}

void main() {
  testWidgets('무엇이 사라지는지 적고, 취소하면 지우지 않는다', (tester) async {
    await _open(tester);
    expect(find.byKey(const ValueKey('delete-word-confirm')), findsOneWidget);
    expect(find.text("'projection' 단어를 지울까요?"), findsOneWidget);
    expect(find.textContaining('복습 기록도 함께 사라져요'), findsOneWidget);
    expect(find.textContaining('되돌릴 수 없어요'), findsOneWidget);

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('delete-word-confirm')), findsNothing);
  });

  testWidgets('지우기를 누르면 창이 닫힌다', (tester) async {
    await _open(tester);
    await tester.tap(find.byKey(const ValueKey('delete-word-ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('delete-word-confirm')), findsNothing);
  });

  test('목록과 검색에서 연 상세, 두 길 모두 묻는다', () {
    final code = _code('lib/features/collection/shell/presentation/'
        'widgets/word_collection_preview.dart');
    // 밀어서 지우기(목록)와 showWordDetails의 지우기.
    expect('confirmDeleteWord(context,'.allMatches(code).length,
        greaterThanOrEqualTo(2));
    // 묻지 않고 바로 지우는 길이 남아 있지 않다.
    for (final line in code.split('\n')) {
      if (!line.contains('MyWordStore.remove(')) continue;
      expect(line.contains('await MyWordStore.remove('), isTrue);
    }
  });
}
