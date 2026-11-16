// 커뮤니티 푸시를 누르면 그 글로 간다(5차 379).
//
// 서버는 오래전부터 routePath를 함께 보내는데 앱이 읽지 않았다. 그래서
// 알림을 눌러도 앱만 열리고 보던 화면 그대로였다.
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/infrastructure/services/firebase/firebase_messaging_service.dart';

void main() {
  test('앱 안의 길이면 그 길을 돌려준다', () {
    expect(pushRoute({'routePath': '/community/board/abc'}),
        '/community/board/abc');
  });

  test('비었거나 없으면 옮기지 않는다', () {
    expect(pushRoute(null), isNull);
    expect(pushRoute({}), isNull);
    expect(pushRoute({'routePath': ''}), isNull);
    expect(pushRoute({'routePath': '   '}), isNull);
  });

  test('바깥 주소나 이상한 값은 받지 않는다', () {
    expect(pushRoute({'routePath': 'https://example.com'}), isNull);
    expect(pushRoute({'routePath': '//example.com'}), isNull);
    expect(pushRoute({'routePath': 'community/board/abc'}), isNull);
  });

  test('누른 알림의 길로 옮긴다', () {
    final moved = <String>[];
    FirebaseMessagingService.go = moved.add;
    addTearDown(() => FirebaseMessagingService.go = (_) {});

    FirebaseMessagingService.handleOpened(
        const RemoteMessage(data: {'routePath': '/community/question/q1'}));
    expect(moved, ['/community/question/q1']);

    FirebaseMessagingService.handleOpened(const RemoteMessage(data: {}));
    FirebaseMessagingService.handleOpened(null);
    expect(moved.length, 1);
  });

  test('앱이 켜질 때 누름을 듣는다', () {
    final service = File(
            'lib/core/infrastructure/services/firebase/firebase_messaging_service.dart')
        .readAsStringSync();
    expect(service, contains('onMessageOpenedApp'));
    expect(service, contains('getInitialMessage'));

    final bootstrap =
        File('lib/core/app/bootstrap/bootstrap.dart').readAsStringSync();
    expect(bootstrap, contains('listenForNotificationTaps'));
  });

  test('서버가 보내는 값 이름과 같다', () {
    final fn = File('functions/src/communityNotifications.ts').readAsStringSync();
    expect(fn, contains('routePath: payload.routePath'));
  });
}
