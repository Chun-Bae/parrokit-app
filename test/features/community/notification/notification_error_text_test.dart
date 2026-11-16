// 알림 화면은 예외 글 대신 사람 말로 알린다(5차 309).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/community/notification/domain/entities/community_notification_item.dart';
import 'package:parrokit/features/community/notification/presentation/notification_error_text.dart';
import 'package:parrokit/features/community/notification/presentation/providers/community_notification_provider.dart';
import 'package:parrokit/features/community/notification/presentation/sections/community_notification_list_section.dart';

class _EmptyProvider extends ChangeNotifier
    implements CommunityNotificationProvider {
  int refreshCount = 0;

  @override
  bool get isLoading => false;

  @override
  List<CommunityNotificationItem> get notifications => const [];

  @override
  String? get errorMessage => null;

  @override
  Future<void> refresh() async => refreshCount++;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  test('무엇을 하다 실패했는지에 맞는 말을 쓴다', () {
    final failure = Exception('boom');
    expect(notificationErrorText(NotificationJob.load, failure),
        '알림을 불러오지 못했어요. 잠시 뒤 다시 해 주세요.');
    expect(notificationErrorText(NotificationJob.read, failure),
        '읽음으로 바꾸지 못했어요. 잠시 뒤 다시 해 주세요.');
    expect(notificationErrorText(NotificationJob.delete, failure),
        '알림을 지우지 못했어요. 잠시 뒤 다시 해 주세요.');
  });

  test('인터넷이 끊긴 것이면 그렇게 말한다', () {
    const offline = '[cloud_firestore/unavailable] Failed to get document '
        'because the client is offline.';
    expect(notificationErrorText(NotificationJob.load, offline),
        contains('인터넷'));
    expect(notificationErrorText(NotificationJob.delete, offline),
        contains('인터넷'));
  });

  test('예외 글을 그대로 담지 않는다', () {
    // 빨간 띠에 `[cloud_firestore/...]`가 그대로 떴었다.
    final code = File(
            'lib/features/community/notification/presentation/providers/community_notification_provider.dart')
        .readAsStringSync();
    expect(code.contains('_errorMessage = e.toString()'), isFalse);
    expect(code.contains('_errorMessage = error.toString()'), isFalse);
    expect(code, contains('notificationErrorText('));
  });

  test('알림 메뉴 단추는 알림이 없어도 열린다', () {
    // 못 불러왔을 때 '새로 고침'으로 갈 길이 그 메뉴뿐이다.
    final code = File(
            'lib/features/community/notification/presentation/community_notification_screen.dart')
        .readAsStringSync()
        .replaceAll(RegExp(r'\s+'), ' ');
    expect(code, contains("ValueKey('open-notification-actions')"));
    expect(
        code.contains('onPressed: provider.hasNotifications ? () => '
            '_showNotificationActionsSheet'),
        isFalse);
  });

  testWidgets('알림이 없어도 당겨서 새로 고칠 수 있다', (tester) async {
    final provider = _EmptyProvider();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CommunityNotificationListSection(provider: provider),
      ),
    ));

    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(provider.refreshCount, 1);
  });
}
