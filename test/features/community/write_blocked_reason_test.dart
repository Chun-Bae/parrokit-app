// 글쓰기 '올리기'가 꺼진 까닭(5차). 게시판·질문·투표가 같은 말을 쓴다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/community/shared/presentation/write_blocked_reason.dart';

/// 포매터가 어디서 줄을 바꿔도 같은 코드로 보이게 띄어쓰기를 하나로 만든다.
String _flat(String code) => code.replaceAll(RegExp(r'\s+'), ' ');

void main() {
  // 차례는 화면에 놓인 차례다(5차 495). 게시판은 위에서부터 주제·제목·내용인데
  // 제목부터 물어서, 빈 화면이 맨 위의 주제를 건너뛰고 제목을 가리켰다.
  test('빠진 것을 화면에 놓인 차례대로 하나씩 알려 준다', () {
    // 아무것도 안 고른 게시판: 맨 위 칸인 주제부터.
    expect(
        writeBlockedReason(
            hasTitle: false, hasContent: false, hasTopic: false),
        '주제를 골라 주세요.');
    expect(
        writeBlockedReason(hasTitle: false, hasContent: false, hasTopic: true),
        '제목을 적어 주세요.');
    expect(
        writeBlockedReason(hasTitle: true, hasContent: false, hasTopic: true),
        '내용을 적어 주세요.');
    // 제목·내용을 먼저 쓴 사람도 마지막에 맨 위로 돌아가지 않는다.
    expect(
        writeBlockedReason(hasTitle: true, hasContent: true, hasTopic: false),
        '주제를 골라 주세요.');
  });

  // 주제가 없는 화면(질문·투표)은 제목부터다.
  test('주제를 쓰지 않는 화면은 제목부터 묻는다', () {
    expect(
        writeBlockedReason(hasTitle: false, hasContent: false), '제목을 적어 주세요.');
    expect(
        writeBlockedReason(hasTitle: true, hasContent: false), '내용을 적어 주세요.');
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
        '항목을 2개 이상 적어 주세요.',
      );
    });

    test('빈 보기 칸이 있으면 채우라고 한다', () {
      expect(
        writeBlockedReason(
            hasTitle: true,
            hasContent: true,
            optionCount: 3,
            filledOptionCount: 2),
        '빈 항목 칸을 채워 주세요.',
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
      expect(code, contains("showToast(_blockedReason"), reason: path);
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
    // 눌렀을 때 뜨는 토스트는 2.5초면 사라져서, 까닭은 화면에도 적어 둔다(5차).
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
    // 토스트는 2.5초면 사라져서, 글자 수 옆에도 그대로 적는다(5차).
    final code = File(
            'lib/features/community/question/presentation/question_write_screen.dart')
        .readAsStringSync();
    expect(code, contains("ValueKey('question-blocked-reason')"));
    expect(code, contains('if (_blockedReason case final reason?)'));
  });

  test('꺼진 단추 안내와 올리기 검사가 같은 말을 쓴다(5차 433)', () {
    // 전에는 단추 아래는 '게시판을 골라 주세요', 올리면 '주제를 골라
    // 주세요'였다. 같은 상황을 두 말로 불렀다.
    final validator = File(
            'lib/features/community/shell/domain/validators/post_validator.dart')
        .readAsStringSync();
    for (final name in [
      'writeNeedsTitleMessage',
      'writeNeedsContentMessage',
      'writeNeedsTopicMessage',
    ]) {
      expect(validator, contains(name), reason: name);
    }
    expect(validator, isNot(contains("'제목을 적어 주세요.'")));
    expect(validator, isNot(contains("'주제를 골라 주세요.'")));
    expect(validator, isNot(contains('등록할 수 있습니다')));
  });

  test('보기 수 안내가 실제 조건과 맞는다(5차 433)', () {
    // 막는 조건은 2개 미만이다. '2개 넘게'라고 하면 3개부터로 읽힌다.
    expect(writeNeedsTwoOptionsMessage, contains('2개 이상'));
    expect(
      writeBlockedReason(
          hasTitle: true, hasContent: true, optionCount: 2, filledOptionCount: 2),
      isNull,
      reason: '보기 2개면 올릴 수 있다',
    );
  });
}
