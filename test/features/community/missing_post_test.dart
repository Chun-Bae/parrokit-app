// 지워졌거나 못 여는 글은 가짜 글이나 글자 한 줄로 때우지 않는다(5차).
//
// 게시판은 제목이 '게시글을 찾을 수 없습니다.'인 Post를 만들어 보통 글처럼
// 그렸고(공감·스크랩·댓글칸이 살아 있었다), 질문·투표는 글자 한 줄만 있었다.
// 투표는 그 화면에 위 바가 없어 뒤로 갈 길도 없었다.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/widgets/app_empty_state.dart';
import 'package:parrokit/features/community/shell/presentation/missing_post_view.dart';

String _code(String path) => File(path)
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('안내는 글 종류에 맞는 말로, 앱 말투로 적는다', () {
    expect(missingPostTitle('board'), '글을 볼 수 없어요');
    expect(missingPostTitle('question'), '질문을 볼 수 없어요');
    expect(missingPostTitle('vote'), '투표를 볼 수 없어요');
    // '투표을'이 되지 않는지 함께 본다.
    for (final line in [
      missingPostTitle('board'),
      missingPostDescription,
      missingPostBackLabel,
    ]) {
      expect(line.contains('습니다'), isFalse, reason: line);
    }
  });

  testWidgets('안내 화면에는 뒤로 갈 길이 있다', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: MissingPostView(boardType: 'vote', appBarTitle: '투표'),
    ));

    expect(find.byType(AppEmptyState), findsOneWidget);
    expect(find.text('투표를 볼 수 없어요'), findsOneWidget);
    // 위 바의 뒤로 버튼과 본문의 버튼, 두 길.
    expect(find.byTooltip('뒤로'), findsOneWidget);
    expect(find.text(missingPostBackLabel), findsOneWidget);
  });

  test('세 상세 화면 모두 가짜 글이나 한 줄 글자를 쓰지 않는다', () {
    final board = _code(
        'lib/features/community/board/presentation/board_view_screen.dart');
    final question = _code(
        'lib/features/community/question/presentation/question_view_screen.dart');
    final vote = _code(
        'lib/features/community/vote/presentation/vote_view_screen.dart');

    expect(board.contains('게시글을 찾을 수 없습니다.'), isFalse);
    expect(question.contains('질문을 찾을 수 없습니다.'), isFalse);
    expect(vote.contains('투표를 찾을 수 없습니다.'), isFalse);
    for (final source in [board, question, vote]) {
      expect(source.contains('MissingPostView'), isTrue);
    }
  });
}
