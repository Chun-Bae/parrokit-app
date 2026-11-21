// 연습 알림을 누르면 홈(앵무새 무대)으로 간다(5차 378).
//
// 전에는 표(payload)도 없고 누름을 받는 곳도 없어서, 알림을 눌러도 보던
// 화면이 그대로였다. 연습하라고 부른 알림인데 갈 곳이 없었다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/app/router/app_routes.dart';
import 'package:parrokit/core/infrastructure/services/local_notification_service.dart';

void main() {
  test('연습 알림 표는 홈으로 간다', () {
    expect(reminderRouteFor(practiceReminderPayload), AppRoutes.dashboardPath);
  });

  test('모르는 표나 표가 없으면 옮기지 않는다', () {
    expect(reminderRouteFor(null), isNull);
    expect(reminderRouteFor(''), isNull);
    expect(reminderRouteFor('something_else'), isNull);
  });

  test('누름을 받으면 그 길로 옮긴다', () {
    final moved = <String>[];
    LocalNotificationService.go = moved.add;
    addTearDown(() => LocalNotificationService.go = (_) {});

    LocalNotificationService.handleTap(practiceReminderPayload);
    expect(moved, [AppRoutes.dashboardPath]);

    LocalNotificationService.handleTap('etc');
    expect(moved.length, 1);
  });

  test('문장 id를 실은 표도 홈으로 간다(5차 508)', () {
    expect(
      reminderRouteFor(practiceReminderPayloadFor('s1')),
      AppRoutes.dashboardPath,
    );
    expect(reminderSentenceIdFor(practiceReminderPayloadFor('s1')), 's1');
    // id가 없으면 예전 표 그대로다.
    expect(practiceReminderPayloadFor(''), practiceReminderPayload);
    expect(practiceReminderPayloadFor('  '), practiceReminderPayload);
    expect(reminderSentenceIdFor(practiceReminderPayload), isNull);
    expect(reminderSentenceIdFor('something_else'), isNull);
    expect(reminderSentenceIdFor(null), isNull);
  });

  test('문장 id가 실려 있으면 그 문장 시트까지 연다(5차 508)', () {
    final moved = <String>[];
    final opened = <String>[];
    LocalNotificationService.go = moved.add;
    LocalNotificationService.openSentence = (id) async => opened.add(id);
    addTearDown(() {
      LocalNotificationService.go = (_) {};
      LocalNotificationService.openSentence = (_) async {};
    });

    LocalNotificationService.handleTap(practiceReminderPayloadFor('s1'));
    expect(moved, [AppRoutes.dashboardPath]);
    expect(opened, ['s1']);

    // id가 없는 예전 표는 홈까지만 간다.
    LocalNotificationService.handleTap(practiceReminderPayload);
    expect(moved.length, 2);
    expect(opened, ['s1']);
  });

  test('예약할 때 표를 붙이고, 누름을 받는 길도 걸어 둔다', () {
    final code =
        File('lib/core/infrastructure/services/local_notification_service.dart')
            .readAsStringSync();
    expect(code, contains('payload: practiceReminderPayloadFor('));
    expect(code, contains('onDidReceiveNotificationResponse:'));
    // 알림을 눌러 앱이 켜진 경우도 본다.
    expect(code, contains('getNotificationAppLaunchDetails'));

    final bootstrap =
        File('lib/core/app/bootstrap/bootstrap.dart').readAsStringSync();
    expect(bootstrap, contains('handleLaunchByNotification'));
  });
}
