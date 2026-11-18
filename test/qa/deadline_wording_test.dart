// 마감을 가리키는 말을 한 가지로 쓴다(5차 496).
//
// 앱은 투표·질문이 끝나는 때를 어디서나 '마감'이라 부른다 - 카드의
// 'N일 뒤 마감', 거르개 '마감', 알림 '투표가 마감됐어요'(479). 그런데
// 투표 만들기만 '투표 진행 기간 · N일 동안'이라 다른 설정처럼 보였고,
// 질문 만들기는 'N일 후'로 앱의 'N일 뒤'와 갈려 있었다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/community/shell/domain/community_deadline.dart';

String _code(String path) => File(path)
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

const _voteWrite =
    'lib/features/community/vote/presentation/vote_write_screen.dart';
const _questionWrite =
    'lib/features/community/question/presentation/question_write_screen.dart';

void main() {
  test('만드는 화면 둘이 같은 이름으로 묻는다', () {
    for (final path in [_voteWrite, _questionWrite]) {
      expect(_code(path), contains('마감 기한'), reason: path);
    }
    // 투표만 '진행 기간'이라 부르던 것이 돌아오지 않는다.
    expect(_code(_voteWrite).contains('투표 진행 기간'), isFalse);
  });

  test("며칠 뒤인지는 '뒤'로 적는다", () {
    expect(_code(_voteWrite), contains('일 뒤'));
    expect(_code(_voteWrite).contains('일 동안'), isFalse);
    expect(_code(_questionWrite), contains('일 뒤'));
    expect(_code(_questionWrite).contains('일 후'), isFalse);
  });

  test('목록 카드도 같은 말을 쓴다', () {
    // 만드는 화면에서 '3일 뒤'를 고르면 카드에 '3일 뒤 마감'으로 보인다.
    final label = communityDeadlineLabel(
      DateTime(2026, 11, 21, 12),
      DateTime(2026, 11, 18, 12),
    );
    expect(label, '3일 뒤 마감');
  });
}
