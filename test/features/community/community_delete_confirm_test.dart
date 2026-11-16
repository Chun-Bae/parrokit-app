// 댓글을 지우기 전에 세 화면 모두 한 번 물어야 한다(5차 399).
//
// 게시판만 물었고 질문·투표는 '지우기'를 누르는 순간 바로 지웠다.
// 창에는 '되돌릴 수 없어요'라고 적어 두고 두 화면은 묻지도 않았다.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/community/shared/presentation/community_delete_confirm.dart';

String _code(String path) => File(path)
    .readAsStringSync()
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

Future<void> _open(
    WidgetTester tester, Future<bool> Function(BuildContext) ask) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async => ask(context),
          child: const Text('열기'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('취소하면 false, 지우기를 누르면 true', (tester) async {
    await _open(tester, confirmDeleteComment);
    expect(find.byKey(const ValueKey('delete-comment-confirm')), findsOneWidget);
    expect(find.text('이 댓글을 지울까요?\n지우면 되돌릴 수 없어요.'), findsOneWidget);

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('delete-comment-confirm')), findsNothing);

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete-comment-confirm-ok')));
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

  testWidgets('글·질문·투표는 그 이름으로 묻는다(5차 400)', (tester) async {
    for (final kind in ['글', '질문', '투표']) {
      await _open(tester, (c) => confirmDeletePost(c, kind: kind));
      expect(find.byKey(const ValueKey('delete-post-confirm')), findsOneWidget);
      expect(find.text('$kind 지우기'), findsOneWidget);
      // '이 질문을'·'이 투표를'처럼 조사도 맞춘다.
      expect(find.textContaining('지우면 되돌릴 수 없어요'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
    }
  });

  test('글 지우기도 세 화면이 같은 창을 쓴다(5차 400)', () {
    const screens = [
      ('lib/features/community/board/presentation/board_view_screen.dart', '글'),
      (
        'lib/features/community/question/presentation/question_view_screen.dart',
        '질문'
      ),
      ('lib/features/community/vote/presentation/vote_view_screen.dart', '투표'),
    ];
    for (final (path, kind) in screens) {
      final code = _code(path);
      expect(code, contains("confirmDeletePost(context, kind: '$kind')"),
          reason: path);
      expect(code, isNot(contains("const Text('글 지우기'")), reason: path);
    }
  });
}
