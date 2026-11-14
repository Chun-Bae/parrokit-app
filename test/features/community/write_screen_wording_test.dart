// 커뮤니티 글쓰기 세 화면의 말투(5차).
//
// '주제를 선택해주세요.', '제목을 입력하세요.', '…할 수 있습니다.'처럼
// '~하세요/~해주세요/~습니다'가 섞여 있어, 앱의 다른 화면('~어요')과 달랐다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _screens = [
  'lib/features/community/board/presentation/board_write_screen.dart',
  'lib/features/community/question/presentation/question_write_screen.dart',
  'lib/features/community/vote/presentation/vote_write_screen.dart',
  'lib/features/community/shell/presentation/sections/community_shell_write_sheet.dart',
];

/// 주석을 뺀 코드만 본다(왜 바꿨는지 주석에는 옛 문구가 남는다).
String _code(String path) => File(path)
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('글쓰기 화면 글에 딱딱한 말투가 없다', () {
    for (final path in _screens) {
      final code = _code(path);
      for (final bad in ['습니다', '하세요.', '해주세요']) {
        expect(code.contains(bad), isFalse, reason: '$path: $bad');
      }
    }
  });

  test('글쓰기 고르는 시트의 줄 이름이 목록 버튼과 같다', () {
    final sheet = _code(_screens[3]);
    // 목록의 버튼은 '글쓰기'·'질문하기'·'투표 만들기'다.
    expect(sheet, contains("title: '글쓰기'"));
    expect(sheet, contains("title: '질문하기'"));
    expect(sheet, contains("title: '투표 만들기'"));
  });

  test('화면 제목이 눌러서 들어온 버튼 이름과 같다', () {
    // 예전에는 '게시글 작성'·'질문 작성'·'투표 작성'이라 들어온 버튼과 달랐다.
    expect(_code(_screens[0]), contains("'글쓰기'"));
    expect(_code(_screens[1]), contains("'질문하기'"));
    expect(_code(_screens[2]), contains("'투표 만들기'"));
  });

  test('제목 칸 안내는 세 화면이 같은 꼴이다', () {
    expect(_code(_screens[0]), contains("hintText: '제목을 적어 주세요'"));
    expect(_code(_screens[1]), contains("hintText: '제목을 적어 주세요'"));
    // 투표는 무엇의 제목인지 밝힌다.
    expect(_code(_screens[2]), contains("hintText: '투표 제목을 적어 주세요'"));
  });
}
