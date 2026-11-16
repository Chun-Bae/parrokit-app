// 질문 화면이 '답변'과 '답글'을 섞어 쓰지 않는지 본다.
//
// 질문에 바로 달리는 글은 답변(채택·보상·커뮤니티 메뉴가 그렇게 부른다),
// 그 답변에 달리는 글은 답글이다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/community/question/presentation/question_words.dart';

String _code(String path) => File(path)
    .readAsStringSync()
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('머리말은 답변 수를 센다', () {
    expect(questionAnswerCountLabel(0), '답변 0');
    expect(questionAnswerCountLabel(3), '답변 3');
  });

  test('입력칸은 답변과 답글을 가려 부른다', () {
    expect(questionInputHint(replying: false), '답변을 남겨 보세요');
    expect(questionInputHint(replying: true), '답글을 남겨 보세요');
  });

  test('안내 글이 앱 말투다', () {
    for (final message in [
      questionNoAnswersMessage,
      questionBlockedAnswerMessage,
      questionAcceptMessage(30),
    ]) {
      expect(message, isNot(contains('습니다')), reason: message);
      expect(message, isNot(contains('습니까')), reason: message);
    }
    expect(questionAcceptMessage(30), contains('크래커 30개'));
    expect(questionAcceptMessage(30), contains('채택할까요?'));
  });

  test('질문 머리 버튼은 답변 쓰기, 답변 아래는 답글 쓰기', () {
    expect(questionWriteAnswerLabel, '답변 쓰기');
    final code = _code(
        'lib/features/community/question/presentation/question_view_screen.dart');
    expect(code, contains('label: questionWriteAnswerLabel'));
    expect(code, contains('CommentReplyButton('));
  });

  test('화면이 이 글들을 쓴다', () {
    final code = _code(
        'lib/features/community/question/presentation/question_view_screen.dart');
    expect(code, contains('questionAcceptMessage('));
    expect(code, contains('questionNoAnswersMessage'));
    expect(code, contains('questionBlockedAnswerMessage'));
    expect(code, isNot(contains('채택하시겠습니까')));
    expect(code, isNot(contains('첫 번째 답변을 남겨보세요')));
    expect(code, isNot(contains('차단된 사용자의 답변입니다')));
  });
}
