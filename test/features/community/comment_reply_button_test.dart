// 세 화면(게시판·투표·질문)의 '답글 쓰기'가 같은 모양·같은 말이어야 한다.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/features/community/shared/presentation/widgets/comment_reply_button.dart';

String _code(String path) => File(path)
    .readAsStringSync()
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

Widget _wrap(Widget child) {
  final cs = ColorScheme.fromSeed(seedColor: Colors.blue);
  return MaterialApp(
    theme: ThemeData(
      colorScheme: cs,
      textTheme: appTextTheme(cs, isDark: false),
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('아이콘과 이름을 함께 보여 준다', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_wrap(CommentReplyButton(
      onTap: () => taps++,
      color: Colors.black,
    )));

    expect(find.text('답글 쓰기'), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);

    await tester.tap(find.text('답글 쓰기'));
    expect(taps, 1);
  });

  testWidgets('아이콘과 글자가 같은 색을 쓴다', (tester) async {
    await tester.pumpWidget(_wrap(CommentReplyButton(
      onTap: () {},
      color: const Color(0xFF123456),
    )));

    final icon = tester.widget<Icon>(find.byIcon(Icons.chat_bubble_outline));
    final text = tester.widget<Text>(find.text('답글 쓰기'));
    expect(icon.color, const Color(0xFF123456));
    expect(text.style?.color, const Color(0xFF123456));
  });

  test('세 화면이 모두 이 버튼을 쓴다', () {
    const paths = [
      'lib/features/community/board/presentation/widgets/board_comment_item.dart',
      'lib/features/community/vote/presentation/vote_view_screen.dart',
      'lib/features/community/question/presentation/question_view_screen.dart',
    ];
    for (final path in paths) {
      final code = _code(path);
      expect(code, contains('CommentReplyButton('), reason: path);
      // 같은 말을 손으로 또 적지 않는다.
      expect(code, isNot(contains("Text('답글 쓰기'")), reason: path);
      expect(code, isNot(contains("tooltip: '답글 쓰기'")), reason: path);
    }
  });
}
