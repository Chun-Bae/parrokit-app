import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/sentence_import_method_dialog.dart';

Future<void> openDialog(
  WidgetTester tester,
  void Function(SentenceImportSource?) onResult,
) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async => onResult(
              await showDialog<SentenceImportSource>(
                  context: context,
                  builder: (_) => const SentenceImportMethodDialog())),
          child: const Text('열기'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('헤드에 제목, 바디에 도움말 1쪽, 푸터에 주소·파일 선택이 있다', (tester) async {
    await openDialog(tester, (_) {});
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('import-head')),
            matching: find.text('CSV·엑셀에서 가져오기')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('import-format-sample')), findsOneWidget);
    expect(find.byKey(const ValueKey('import-sample-image')), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
    final footer = find.byKey(const ValueKey('import-footer'));
    expect(
        find.descendant(
            of: footer,
            matching: find.byKey(const ValueKey('url-import-input'))),
        findsOneWidget);
    expect(
        find.descendant(
            of: footer,
            matching: find.byKey(const ValueKey('import-from-file'))),
        findsOneWidget);
  });

  testWidgets('푸터에서 파일을 고르면 파일 방식이 돌아온다', (tester) async {
    SentenceImportSource? result;
    var done = false;
    await openDialog(tester, (value) {
      result = value;
      done = true;
    });
    await tester.tap(find.byKey(const ValueKey('import-from-file')));
    await tester.pumpAndSettle();
    expect(done, isTrue);
    expect(result, isNotNull);
    expect(result!.url, isNull);
  });

  testWidgets('푸터에서 주소를 입력해 가져오면 그 주소가 돌아온다', (tester) async {
    SentenceImportSource? result;
    await openDialog(tester, (value) => result = value);
    await tester.enterText(find.byKey(const ValueKey('url-import-input')),
        '  https://example.com/a.csv ');
    await tester.tap(find.byKey(const ValueKey('url-import-confirm')));
    await tester.pumpAndSettle();
    expect(result?.url, 'https://example.com/a.csv');
  });

  testWidgets('옆으로 넘기면 도움말 2, 3쪽이 나오고 푸터는 그대로 보인다', (tester) async {
    await openDialog(tester, (_) {});
    final pages = find.byKey(const ValueKey('import-pages'));
    final top = tester.getTopLeft(pages);

    await tester.dragFrom(top + const Offset(200, 3), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.textContaining('문장 열 하나'), findsNothing);
    expect(find.textContaining('UTF-8'), findsOneWidget);
    expect(find.byKey(const ValueKey('import-footer')), findsOneWidget);

    await tester.dragFrom(top + const Offset(200, 3), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('3 / 3'), findsOneWidget);
    expect(find.textContaining('링크가 있는 모든 사용자 보기'), findsOneWidget);
    expect(find.text('아이클라우드 드라이브'), findsOneWidget);
    expect(find.byKey(const ValueKey('url-import-input')), findsOneWidget);
  });

  testWidgets('이전·다음 버튼으로 쪽을 넘긴다', (tester) async {
    await openDialog(tester, (_) {});
    // 첫 쪽에서는 이전을 누를 수 없다.
    expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('import-prev')))
            .onPressed,
        isNull);
    await tester.tap(find.byKey(const ValueKey('import-next')));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('import-next')));
    await tester.pumpAndSettle();
    expect(find.text('3 / 3'), findsOneWidget);
    expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('import-next')))
            .onPressed,
        isNull);
    await tester.tap(find.byKey(const ValueKey('import-prev')));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
  });

  testWidgets('예시 이미지를 누르면 크게 보고 닫을 수 있다', (tester) async {
    await openDialog(tester, (_) {});
    final image = find.byKey(const ValueKey('import-sample-image'));
    await tester.ensureVisible(image);
    await tester.pumpAndSettle();
    await tester.tap(image);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('import-sample-viewer')), findsOneWidget);
    await tester.tap(find.byTooltip('닫기').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('import-sample-viewer')), findsNothing);
    expect(find.byKey(const ValueKey('import-method-dialog')), findsOneWidget);
  });
}
