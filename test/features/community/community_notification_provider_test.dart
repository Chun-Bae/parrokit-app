import 'dart:async';

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

/// 계정별로 불러오기 완료 시점을 테스트가 정하는 가짜 저장소.
class _Repo extends Fake implements CommunityNotificationRepository {
  final fetches = <String, Completer<List<CommunityNotificationItem>>>{};
  final streams = <String, StreamController<List<CommunityNotificationItem>>>{};

  Completer<List<CommunityNotificationItem>> fetchOf(String userId) =>
      fetches.putIfAbsent(userId, Completer.new);

  StreamController<List<CommunityNotificationItem>> streamOf(String userId) =>
      streams.putIfAbsent(userId, StreamController.broadcast);

  @override
  Future<List<CommunityNotificationItem>> fetchNotifications(String userId) =>
      fetchOf(userId).future;

  @override
  Stream<List<CommunityNotificationItem>> watchNotifications(String userId) =>
      streamOf(userId).stream;
}

class _Messaging extends Fake implements FirebaseMessagingService {
  @override
  Future<void> syncUserToken(String userId) async {}

  @override
  Future<void> clearUserToken(String userId) async {}

  @override
  void dispose() {}
}

CommunityNotificationItem _item(String id, String user) =>
    CommunityNotificationItem(
      id: id,
      recipientUserId: user,
      notificationType: 'comment',
      boardType: 'board',
      postId: 'p',
      actorId: 'x',
      title: 't',
      body: 'b',
      isRead: false,
      createdAt: DateTime(2026, 11, 14),
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

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('불러오고 실시간으로 바뀐 알림을 반영한다', () async {
    final repo = _Repo();
    final p = _provider(repo)..syncUser('a');
    final activating = p.activate();
    repo.fetchOf('a').complete([_item('a1', 'a')]);
    await activating;
    expect(p.notifications.map((n) => n.id), ['a1']);
    expect(p.isLoading, isFalse);

    repo.streamOf('a').add([_item('a1', 'a'), _item('a2', 'a')]);
    await _settle();
    expect(p.unreadCount, 2);
  });

  test('불러오는 사이 계정이 바뀌면 이전 계정의 알림을 넣지 않는다', () async {
    final repo = _Repo();
    final p = _provider(repo)..syncUser('a');
    final activating = p.activate();

    p.syncUser('b');
    repo.fetchOf('b').complete([_item('b1', 'b')]);
    await _settle();
    // 늦게 끝난 이전 계정 요청.
    repo.fetchOf('a').complete([_item('a1', 'a')]);
    await activating;
    await _settle();

    expect(p.notifications.map((n) => n.id), ['b1']);
    // 이전 계정의 실시간 구독은 붙이지 않는다.
    expect(repo.streamOf('a').hasListener, isFalse);
    expect(repo.streamOf('b').hasListener, isTrue);

    repo.streamOf('a').add([_item('a9', 'a')]);
    await _settle();
    expect(p.notifications.map((n) => n.id), ['b1']);
  });

  test('새로고침 중 로그아웃하면 늦게 온 결과를 버린다', () async {
    final repo = _Repo();
    final p = _provider(repo)..syncUser('a');
    final activating = p.activate();
    repo.fetchOf('a').complete(<CommunityNotificationItem>[]);
    await activating;

    repo.fetches.remove('a');
    final refreshing = p.refresh();
    p.syncUser(null);
    repo.fetchOf('a').complete([_item('a1', 'a')]);
    await refreshing;

    expect(p.notifications, isEmpty);
    expect(p.isLoading, isFalse);
  });
}
