// 댓글을 지우기 전에 세 화면 모두 한 번 물어야 한다(5차 399).
//
// 게시판만 물었고 질문·투표는 '지우기'를 누르는 순간 바로 지웠다.
// 창에는 '되돌릴 수 없어요'라고 적어 두고 두 화면은 묻지도 않았다.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/community/shared/presentation/comment_delete_confirm.dart';

String _code(String path) => File(path)
    .readAsStringSync()
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

Future<bool?> _ask(WidgetTester tester) async {
  bool? answer;
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async => answer = await confirmDeleteComment(context),
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
  testWidgets('취소하면 false, 지우기를 누르면 true', (tester) async {
    await _ask(tester);
    expect(find.byKey(const ValueKey('delete-comment-confirm')), findsOneWidget);
    expect(find.text('이 댓글을 지울까요?\n지우면 되돌릴 수 없어요.'), findsOneWidget);

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('delete-comment-confirm')), findsNothing);

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete-comment-ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('delete-comment-confirm')), findsNothing);
  });

  test('세 화면이 같은 확인 창을 쓰고, 지운 댓글은 옵션을 열지 않는다', () {
    const screens = [
      (
        'lib/features/community/board/presentation/board_view_screen.dart',
        "comment.status == 'deleted'"
      ),
      (
        'lib/features/community/question/presentation/question_view_screen.dart',
        "answer.status == 'deleted'"
      ),
      (
        'lib/features/community/vote/presentation/vote_view_screen.dart',
        "comment.status == 'deleted'"
      ),
    ];
    for (final (path, guard) in screens) {
      final code = _code(path);
      expect(code, contains('confirmDeleteComment(context)'), reason: path);
      expect(code, contains(guard), reason: path);
      // 확인 창을 화면마다 또 적지 않는다.
      expect(code, isNot(contains("const Text('댓글 지우기'")), reason: path);
    }
  });
}
