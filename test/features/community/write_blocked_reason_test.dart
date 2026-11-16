// 글쓰기 '올리기'가 꺼진 까닭(5차). 게시판·질문·투표가 같은 말을 쓴다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/community/shared/presentation/write_blocked_reason.dart';

/// 포매터가 어디서 줄을 바꿔도 같은 코드로 보이게 띄어쓰기를 하나로 만든다.
String _flat(String code) => code.replaceAll(RegExp(r'\s+'), ' ');

void main() {
  test('빠진 것을 위에서부터 하나씩 알려 준다', () {
    expect(
        writeBlockedReason(hasTitle: false, hasContent: false), '제목을 적어 주세요.');
    expect(
        writeBlockedReason(hasTitle: true, hasContent: false), '내용을 적어 주세요.');
    expect(
        writeBlockedReason(hasTitle: true, hasContent: true, hasTopic: false),
        '게시판을 골라 주세요.');
  });

  test('다 채우면 막지 않는다', () {
    expect(writeBlockedReason(hasTitle: true, hasContent: true), isNull);
  });

  group('투표 보기', () {
    test('보기가 둘보다 적으면 그렇게 말한다', () {
      expect(
        writeBlockedReason(
            hasTitle: true,
            hasContent: true,
            optionCount: 1,
            filledOptionCount: 1),
        '고를 보기를 2개 넘게 적어 주세요.',
      );
    });

    test('빈 보기 칸이 있으면 채우라고 한다', () {
      expect(
        writeBlockedReason(
            hasTitle: true,
            hasContent: true,
            optionCount: 3,
            filledOptionCount: 2),
        '빈 보기 칸을 채워 주세요.',
      );
    });

    test('다 채우면 막지 않는다', () {
      expect(
        writeBlockedReason(
            hasTitle: true,
            hasContent: true,
            optionCount: 2,
            filledOptionCount: 2),
        isNull,
      );
    });
  });

  test('세 글쓰기 화면이 모두 이 말을 쓴다', () {
    for (final path in [
      'lib/features/community/board/presentation/board_write_screen.dart',
      'lib/features/community/question/presentation/question_write_screen.dart',
      'lib/features/community/vote/presentation/vote_write_screen.dart',
    ]) {
      final code = _flat(File(path).readAsStringSync());
      expect(code, contains('writeBlockedReason('), reason: path);
      // 꺼진 채 눌러도 아무 일이 없던 자리에서 까닭을 말해 준다.
      expect(
          code,
          matches(RegExp(r'showWriteFailedMessage\( ?context, '
              r'_blockedReason')),
          reason: path);
    }
  });

  test('못 올리는 동안에는 단추가 흐리게 보인다', () {
    // 눌러서 까닭을 들을 수 있게 열어 두면서 색까지 진해지면,
    // 올릴 수 있는 것처럼 보인다.
    for (final path in [
      'lib/features/community/question/presentation/question_write_screen.dart',
      'lib/features/community/vote/presentation/vote_write_screen.dart',
    ]) {
      // 줄바꿈은 포매터가 정한다. 띄어쓰기를 하나로 눌러서 본다.
      final code = _flat(File(path).readAsStringSync());
      expect(code, contains('backgroundColor: _isValid'), reason: path);
    }
    final board = _flat(File(
            'lib/features/community/board/presentation/board_write_screen.dart')
        .readAsStringSync());
    expect(board, contains('color: _canComplete'));
  });

  test('세 글쓰기 화면 모두 까닭을 눈에 보이게 적는다', () {
    // 이 화면들에서는 토스트가 그려지지 않는 것을 시뮬레이터에서 봤다(5차).
    const keys = {
      'lib/features/community/board/presentation/board_write_screen.dart':
          'board-blocked-reason',
      'lib/features/community/question/presentation/question_write_screen.dart':
          'question-blocked-reason',
      'lib/features/community/vote/presentation/vote_write_screen.dart':
          'vote-blocked-reason',
    };
    keys.forEach((path, key) {
      final code = File(path).readAsStringSync();
      expect(code, contains("ValueKey('$key')"), reason: path);
      expect(code, contains('if (_blockedReason case final reason?)'),
          reason: path);
    });
  });

  test('질문 글쓰기는 까닭을 아래 줄에 눈으로 보이게 적는다', () {
    // 이 화면에서는 토스트가 그려지지 않는 것을 시뮬레이터에서 봤다(5차).
    // 그래서 글자 수 옆에 그대로 적는다.
    final code = File(
            'lib/features/community/question/presentation/question_write_screen.dart')
        .readAsStringSync();
    expect(code, contains("ValueKey('question-blocked-reason')"));
    expect(code, contains('if (_blockedReason case final reason?)'));
  });
}
