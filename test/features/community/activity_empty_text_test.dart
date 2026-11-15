// 내 활동이 비었을 때의 설명이 그 목록에 맞는 말인지 본다.

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/community/activity/presentation/activity_empty_text.dart';

void main() {
  test('댓글·답변·답글을 가려 부른다', () {
    expect(activityEmptyDescription('board', 'commented'), '글에 남긴 댓글이 여기에 모여요.');
    expect(activityEmptyDescription('question', 'commented'), '질문에 남긴 답변이 여기에 모여요.');
    expect(activityEmptyDescription('vote', 'commented'), '투표에 남긴 댓글이 여기에 모여요.');
    expect(activityEmptyDescription('question', 'commented_reply'),
        '답변에 남긴 답글이 여기에 모여요.');
    expect(activityEmptyDescription('board', 'commented_reply'),
        '댓글에 남긴 답글이 여기에 모여요.');
  });

  test('좋아요한 목록은 글이 아니라 댓글·답변이라고 적는다', () {
    expect(activityEmptyDescription('board', 'liked_comment'), '좋아요한 댓글이 여기에 모여요.');
    expect(activityEmptyDescription('question', 'liked_comment'),
        '좋아요한 답변과 답글이 여기에 모여요.');
  });

  test('공감한 목록은 글·질문으로 가른다', () {
    expect(activityEmptyDescription('board', 'liked'), '공감한 글이 여기에 모여요.');
    expect(activityEmptyDescription('question', 'liked'), '공감한 질문이 여기에 모여요.');
  });

  test('쓰기·투표 안내는 그대로 둔다', () {
    expect(activityEmptyDescription('board', 'written'), '첫 글을 남기면 여기에 모여요.');
    expect(activityEmptyDescription('question', 'written'), '첫 질문을 올리면 여기에 모여요.');
    expect(activityEmptyDescription('vote', 'written'), '마음에 드는 투표에 참여해 보세요.');
    expect(activityEmptyDescription('vote', 'written_posted'), '첫 투표를 만들면 여기에 모여요.');
    expect(activityEmptyDescription('board', 'scraped'), '나중에 다시 볼 글을 스크랩해 두세요.');
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
}
