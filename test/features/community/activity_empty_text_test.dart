// 내 활동이 비었을 때의 설명이 그 목록에 맞는 말인지 본다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/community/activity/presentation/activity_empty_text.dart';

void main() {
  test('댓글·답변·답글을 가려 부른다', () {
    expect(
        activityEmptyDescription('board', 'commented'), '글에 남긴 댓글이 여기에 모여요.');
    expect(activityEmptyDescription('question', 'commented'),
        '질문에 남긴 답변이 여기에 모여요.');
    expect(
        activityEmptyDescription('vote', 'commented'), '투표에 남긴 댓글이 여기에 모여요.');
    expect(activityEmptyDescription('question', 'commented_reply'),
        '답변에 남긴 답글이 여기에 모여요.');
    expect(activityEmptyDescription('board', 'commented_reply'),
        '댓글에 남긴 답글이 여기에 모여요.');
  });

  test('좋아요한 목록은 글이 아니라 댓글·답변이라고 적는다', () {
    expect(activityEmptyDescription('board', 'liked_comment'),
        '좋아요한 댓글이 여기에 모여요.');
    expect(activityEmptyDescription('question', 'liked_comment'),
        '좋아요한 답변과 답글이 여기에 모여요.');
  });

  test('공감한 목록은 글·질문으로 가른다', () {
    expect(activityEmptyDescription('board', 'liked'), '공감한 글이 여기에 모여요.');
    expect(activityEmptyDescription('question', 'liked'), '공감한 질문이 여기에 모여요.');
  });

  test('쓰기·투표 안내는 그대로 둔다', () {
    expect(activityEmptyDescription('board', 'written'), '첫 글을 남기면 여기에 모여요.');
    expect(
        activityEmptyDescription('question', 'written'), '첫 질문을 올리면 여기에 모여요.');
    expect(activityEmptyDescription('vote', 'written'), '마음에 드는 투표에 참여해 보세요.');
    expect(activityEmptyDescription('vote', 'written_posted'),
        '첫 투표를 만들면 여기에 모여요.');
    expect(
        activityEmptyDescription('board', 'scraped'), '나중에 다시 볼 글을 스크랩해 두세요.');
  });

  test('모든 설명이 앱 말투다', () {
    const boards = ['board', 'question', 'vote'];
    const types = [
      'written',
      'written_posted',
      'commented',
      'commented_reply',
      'liked',
      'liked_comment',
      'scraped',
      'unknown',
    ];
    for (final board in boards) {
      for (final type in types) {
        final text = activityEmptyDescription(board, type);
        expect(text, isNot(contains('습니다')), reason: '$board/$type');
        expect(text.endsWith('.'), isTrue, reason: '$board/$type');
      }
    }
  });

  group('총 개수 줄(5차 407)', () {
    test('댓글 좋아요는 공감이 아니라 좋아요라고 센다', () {
      // 글·질문은 엄지 '공감', 댓글·답변은 하트 '좋아요'(89d57b67).
      expect(activityCountLabel('board', 'liked', 3), '총 공감 3개');
      expect(activityCountLabel('board', 'liked_comment', 3), '총 좋아요 3개');
    });

    test('게시판·질문·투표의 이름을 따른다', () {
      expect(activityCountLabel('board', 'written', 1), '총 글 1개');
      expect(activityCountLabel('question', 'written', 1), '총 질문 1개');
      expect(activityCountLabel('vote', 'written_posted', 2), '총 투표 2개');
      expect(activityCountLabel('question', 'commented', 2), '총 답변 2개');
      expect(activityCountLabel('board', 'commented', 2), '총 댓글 2개');
      expect(activityCountLabel('board', 'commented_reply', 2), '총 답글 2개');
      expect(activityCountLabel('board', 'scraped', 0), '총 스크랩 0개');
      expect(activityCountLabel('board', 'unknown', 0), '총 활동 0개');
    });

    // 제목은 '질문 - 스크랩'인데 아래는 '다시 볼 글을 스크랩해 두세요'였다(5차 480).
    test('스크랩 안내도 묶음 이름을 따른다', () {
      expect(activityEmptyDescription('board', 'scraped'),
          '나중에 다시 볼 글을 스크랩해 두세요.');
      expect(activityEmptyDescription('question', 'scraped'),
          '나중에 다시 볼 질문을 스크랩해 두세요.');
      expect(activityEmptyDescription('vote', 'scraped'),
          '나중에 다시 볼 투표를 스크랩해 두세요.');
    });

    test('못 불러오면 그 자리에서 다시 시도할 수 있다', () {
      final code = File('lib/features/community/activity/presentation/'
              'activity_screen.dart')
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(code, contains("ValueKey('activity-retry')"));
      expect(code, contains('onPressed: provider.refresh'));
      // 닫았다 다시 열라고만 하지 않는다.
      expect(code, isNot(contains('잠시 뒤 다시 열어 주세요')));
    });
  });
}
