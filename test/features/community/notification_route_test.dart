// 알림을 누르면 가는 길은 앱과 서버가 같아야 한다(5차 380).
//
// 앱은 알림 목록에서 길을 스스로 만들고, 서버는 푸시에 길을 담아 보낸다.
// 규칙이 어긋나면 같은 알림이라도 목록에서 누를 때와 푸시를 누를 때
// 다른 화면이 열린다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/app/router/app_routes.dart';

void main() {
  test('게시판 종류에 맞는 글 화면으로 간다', () {
    expect(AppRoutes.communityViewPathOf('question', 'q1'),
        '/community/question/q1');
    expect(AppRoutes.communityViewPathOf('vote', 'v1'), '/community/vote/v1');
    expect(AppRoutes.communityViewPathOf('board', 'p1'), '/community/board/p1');
  });

  test('모르는 종류는 게시판으로 본다', () {
    expect(AppRoutes.communityViewPathOf('', 'p1'), '/community/board/p1');
    expect(AppRoutes.communityViewPathOf('etc', 'p1'), '/community/board/p1');
  });

  test('서버가 보내는 길과 규칙이 같다', () {
    final server =
        File('functions/src/communityNotifications.ts').readAsStringSync();
    expect(server, contains(r'return `/community/question/${postId}`'));
    expect(server, contains(r'return `/community/vote/${postId}`'));
    expect(server, contains(r'return `/community/board/${postId}`'));
  });

  test('알림 목록은 그 한 함수만 쓴다', () {
    final code = File(
            'lib/features/community/notification/presentation/sections/community_notification_list_section.dart')
        .readAsStringSync();
    expect(code, contains('AppRoutes.communityViewPathOf'));
    expect(code.contains("case 'question':"), isFalse);
  });
}
