import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/community/notification/presentation/widgets/community_notification_tile.dart';

void main() {
  test("예전 알림의 '일반'을 게시판 글에서만 '게시판'으로 보여준다", () {
    expect(displayNotificationText('일반에 새 댓글이 달렸어요.', 'board'),
        '게시판에 새 댓글이 달렸어요.');
    expect(displayNotificationText('봄배님이 일반에 댓글을 남겼어요.', 'board'),
        '봄배님이 게시판에 댓글을 남겼어요.');
    expect(displayNotificationText('봄배님이 일반의 댓글에 답글을 남겼어요.', 'board'),
        '봄배님이 게시판의 댓글에 답글을 남겼어요.');
  });

  test('다른 게시판·새 문구·닉네임 속 일반은 그대로', () {
    expect(displayNotificationText('질문에 새 댓글이 달렸어요.', 'question'),
        '질문에 새 댓글이 달렸어요.');
    expect(displayNotificationText('게시판에 새 댓글이 달렸어요.', 'board'),
        '게시판에 새 댓글이 달렸어요.');
    expect(displayNotificationText('일반인님이 게시판에 댓글을 남겼어요.', 'board'),
        '일반인님이 게시판에 댓글을 남겼어요.');
  });
}
