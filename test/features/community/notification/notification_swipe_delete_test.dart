// 알림을 밀어서 지울 때, 지우기가 실패하면 제자리로 돌아와야 한다(5차 396).
//
// 전에는 먼저 치우고(onDismissed) 지웠다. 지우기가 실패하면 provider 목록에는
// 그 알림이 그대로라 다시 그려지고, Flutter가
// 'A dismissed Dismissible widget is still part of the tree'로 화면을 깼다.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/infrastructure/services/firebase/firebase_messaging_service.dart';
import 'package:parrokit/features/community/notification/domain/entities/community_notification_item.dart';
import 'package:parrokit/features/community/notification/domain/repositories/community_notification_repository.dart';
import 'package:parrokit/features/community/notification/domain/usecases/delete_all_notifications_usecase.dart';
import 'package:parrokit/features/community/notification/domain/usecases/delete_notification_usecase.dart';
import 'package:parrokit/features/community/notification/domain/usecases/fetch_notifications_usecase.dart';
import 'package:parrokit/features/community/notification/domain/usecases/mark_all_notifications_read_usecase.dart';
import 'package:parrokit/features/community/notification/domain/usecases/mark_notification_read_usecase.dart';
import 'package:parrokit/features/community/notification/domain/usecases/watch_notifications_usecase.dart';
import 'package:parrokit/features/community/notification/presentation/providers/community_notification_provider.dart';
import 'package:parrokit/features/community/notification/presentation/sections/community_notification_list_section.dart';

class _Repo extends Fake implements CommunityNotificationRepository {
  _Repo(this.items);

  List<CommunityNotificationItem> items;
  bool deleteFails = true;
  int deleteCalls = 0;

  final _stream =
      StreamController<List<CommunityNotificationItem>>.broadcast();

  @override
  Future<List<CommunityNotificationItem>> fetchNotifications(String userId) =>
      Future.value(items);

  @override
  Stream<List<CommunityNotificationItem>> watchNotifications(String userId) =>
      _stream.stream;

  @override
  Future<void> deleteNotification({
    required String userId,
    required String notificationId,
  }) async {
    deleteCalls++;
    if (deleteFails) throw Exception('network');
    items = items.where((e) => e.id != notificationId).toList();
    _stream.add(items);
  }
}

class _Messaging extends Fake implements FirebaseMessagingService {
  @override
  Future<void> syncUserToken(String userId) async {}
  @override
  Future<void> clearUserToken(String userId) async {}
  @override
  void dispose() {}
}

CommunityNotificationItem _item(String id) => CommunityNotificationItem(
      id: id,
      recipientUserId: 'u1',
      notificationType: 'comment',
      boardType: 'board',
      postId: 'p1',
      actorId: 'x',
      title: '알림 $id',
      body: '내용 $id',
      isRead: false,
      createdAt: DateTime(2026, 11, 17),
    );

CommunityNotificationProvider _provider(_Repo repo) =>
    CommunityNotificationProvider(
      watchNotificationsUseCase: WatchNotificationsUseCase(repo),
      fetchNotificationsUseCase: FetchNotificationsUseCase(repo),
      markNotificationReadUseCase: MarkNotificationReadUseCase(repo),
      markAllNotificationsReadUseCase: MarkAllNotificationsReadUseCase(repo),
      deleteNotificationUseCase: DeleteNotificationUseCase(repo),
      deleteAllNotificationsUseCase: DeleteAllNotificationsUseCase(repo),
      messagingService: _Messaging(),
    );

Future<void> _pumpList(
    WidgetTester tester, CommunityNotificationProvider vm) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: AnimatedBuilder(
        animation: vm,
        builder: (_, __) => CommunityNotificationListSection(provider: vm),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('지우기가 실패하면 알림이 제자리로 돌아온다', (tester) async {
    final repo = _Repo([_item('n1')]);
    final vm = _provider(repo);
    addTearDown(vm.dispose);
    vm.syncUser('u1');
    await vm.activate();
    await tester.pumpAndSettle();

    await _pumpList(tester, vm);
    expect(find.text('알림 n1'), findsOneWidget);

    await tester.drag(find.text('알림 n1'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(repo.deleteCalls, 1);
    // 치워지지 않고 그대로 있어야 한다. 예전에는 사라졌다가 다시 그려지며 깨졌다.
    expect(find.text('알림 n1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('지워지면 목록에서 사라진다', (tester) async {
    final repo = _Repo([_item('n1')])..deleteFails = false;
    final vm = _provider(repo);
    addTearDown(vm.dispose);
    vm.syncUser('u1');
    await vm.activate();
    await tester.pumpAndSettle();

    await _pumpList(tester, vm);
    await tester.drag(find.text('알림 n1'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(repo.deleteCalls, 1);
    expect(find.text('알림 n1'), findsNothing);
  });

  test('지운 결과를 true/false로 돌려준다', () async {
    final repo = _Repo([_item('n1')]);
    final vm = _provider(repo);
    addTearDown(vm.dispose);
    vm.syncUser('u1');
    await vm.activate();

    expect(await vm.deleteNotification('n1'), isFalse);
    repo.deleteFails = false;
    expect(await vm.deleteNotification('n1'), isTrue);
  });
}
