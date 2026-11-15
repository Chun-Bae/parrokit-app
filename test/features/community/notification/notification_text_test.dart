import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/community/notification/presentation/utils/notification_text.dart';

void main() {
  test("예전 알림의 '일반'을 게시판 글에서만 '게시판'으로 보여준다", () {
    expect(displayNotificationTitle('일반에 새 댓글이 달렸어요.', 'board'),
        '게시판에 새 댓글이 달렸어요.');
    expect(displayNotificationBody('봄배님이 일반에 댓글을 남겼어요.', 'board'),
        '봄배님이 게시판에 댓글을 남겼어요.');
    expect(displayNotificationBody('봄배님이 일반의 댓글에 답글을 남겼어요.', 'board'),
        '봄배님이 게시판의 댓글에 답글을 남겼어요.');
  });

  test('다른 게시판·새 문구·닉네임 속 일반은 그대로', () {
    expect(displayNotificationTitle('질문에 새 댓글이 달렸어요.', 'question'),
        '질문에 새 댓글이 달렸어요.');
    expect(displayNotificationTitle('게시판에 새 댓글이 달렸어요.', 'board'),
        '게시판에 새 댓글이 달렸어요.');
    expect(displayNotificationBody('일반인님이 게시판에 댓글을 남겼어요.', 'board'),
        '일반인님이 게시판에 댓글을 남겼어요.');
  });

  group('예전 투표 마감 알림', () {
    test("'종료'라 적힌 제목을 앱과 같이 '마감'으로 보여준다", () {
      expect(displayNotificationTitle('투표가 종료되었어요.', 'vote'),
          '투표가 마감됐어요.');
      expect(displayNotificationTitle('투표가 마감됐어요.', 'vote'),
          '투표가 마감됐어요.');
    });

    test('투표가 아닌 알림의 같은 문장은 건드리지 않는다', () {
      expect(displayNotificationTitle('투표가 종료되었어요.', 'board'),
          '투표가 종료되었어요.');
    });

    test('본문에 이어 붙은 글 제목을 따옴표로 묶어 보여준다', () {
      expect(displayNotificationBody('오늘 뭐 먹지 결과를 확인해 보세요.', 'vote'),
          "'오늘 뭐 먹지' 결과를 확인해 보세요.");
    });

    test('이미 묶여 있거나 제목이 없으면 그대로', () {
      expect(displayNotificationBody("'오늘 뭐 먹지' 결과를 확인해 보세요.", 'vote'),
          "'오늘 뭐 먹지' 결과를 확인해 보세요.");
      expect(displayNotificationBody('결과를 확인해 보세요.', 'vote'),
          '결과를 확인해 보세요.');
    });

    test('투표가 아닌 알림의 본문은 묶지 않는다', () {
      expect(displayNotificationBody('오늘 뭐 먹지 결과를 확인해 보세요.', 'board'),
          '오늘 뭐 먹지 결과를 확인해 보세요.');
    });
  });
}
