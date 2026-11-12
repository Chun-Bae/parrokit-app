import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/community/notification/data/repositories/community_notification_repository_impl.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late CommunityNotificationRepositoryImpl repository;

  const userId = 'user_1';

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = CommunityNotificationRepositoryImpl(firestore: firestore);
  });

  Future<void> seedNotifications(int count, {bool isRead = false}) async {
    final collection =
        firestore.collection('users').doc(userId).collection('notifications');
    for (var i = 0; i < count; i++) {
      await collection.doc('n_$i').set({
        'type': 'comment',
        'isRead': isRead,
        'createdAt': DateTime(2026, 1, 1).add(Duration(seconds: i)),
      });
    }
    await firestore
        .collection('users')
        .doc(userId)
        .set({'unreadNotificationCount': isRead ? 0 : count});
  }

  Future<List<bool>> readFlags() async {
    final snapshot = await firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .get();
    return snapshot.docs
        .map((d) => d.data()['isRead'] as bool? ?? false)
        .toList();
  }

  Future<int?> unreadCount() async {
    final doc = await firestore.collection('users').doc(userId).get();
    return (doc.data()?['unreadNotificationCount'] as num?)?.toInt();
  }

  // 안 읽은 수(unreadNotificationCount)는 트랜잭션 안에서
  // FieldValue.increment(-1)로 고친다. fake_cloud_firestore는 트랜잭션의
  // set(merge)에서 increment를 기존 값에 적용하지 않고 늘 0 기준으로
  // 계산한다. 그래서 트랜잭션을 쓰는 경로에서는 카운터를 확인하지 않는다.
  // 배치로 0을 그대로 써 넣는 경로(markAllAsRead, deleteAllNotifications)는
  // 확인할 수 있다.

  group('markAsRead', () {
    test('읽지 않은 알림을 읽음으로 바꾼다', () async {
      await seedNotifications(3);

      await repository.markAsRead(userId: userId, notificationId: 'n_1');

      final doc = await firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc('n_1')
          .get();
      expect(doc.data()!['isRead'], true);
      expect(doc.data()!['readAt'], isNotNull);
    });

    test('없는 알림을 읽음 처리해도 던지지 않는다', () async {
      await seedNotifications(1);

      await repository.markAsRead(userId: userId, notificationId: '없는id');

      expect(await readFlags(), [false]);
    });
  });

  group('markAllAsRead', () {
    test('500개를 넘겨도 전부 읽음으로 바꾼다', () async {
      // Firestore WriteBatch는 한 번에 500개까지다. 전에는 한 배치에
      // 통째로 담아서, 이만큼 쌓인 사용자는 "전체 읽음"을 영영 못 했다.
      await seedNotifications(501);

      await repository.markAllAsRead(userId);

      final flags = await readFlags();
      expect(flags, hasLength(501));
      expect(flags.every((read) => read), isTrue);
      expect(await unreadCount(), 0);
    });

    test('안 읽은 것이 없으면 아무것도 하지 않는다', () async {
      await seedNotifications(2, isRead: true);
      await firestore
          .collection('users')
          .doc(userId)
          .set({'unreadNotificationCount': 7});

      await repository.markAllAsRead(userId);

      // 손대지 않으므로 카운터도 그대로다.
      expect(await unreadCount(), 7);
    });
  });

  group('deleteAllNotifications', () {
    test('500개를 넘겨도 전부 지우고 안 읽은 수를 0으로 만든다', () async {
      await seedNotifications(1001);

      await repository.deleteAllNotifications(userId);

      expect(await readFlags(), isEmpty);
      expect(await unreadCount(), 0);
    });
  });

  group('deleteNotification', () {
    test('지정한 알림만 지운다', () async {
      await seedNotifications(3);

      await repository.deleteNotification(
          userId: userId, notificationId: 'n_0');

      final snapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .get();
      expect(snapshot.docs.map((d) => d.id), ['n_1', 'n_2']);
    });
  });
}
