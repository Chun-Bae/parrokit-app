import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/data/models/user.dart';
import 'package:parrokit/features/community/notification/data/settings/notification_prefs.dart';
import 'package:parrokit/features/community/notification/presentation/notification_settings_screen.dart';
import 'package:provider/provider.dart';

class _MockUserProvider extends Mock implements UserProvider {}

void main() {
  group('NotificationPrefs', () {
    test('저장값이 없거나 모양이 다르면 모두 켜진 것으로 본다', () {
      expect(NotificationPrefs.fromMap(null), const NotificationPrefs());
      expect(NotificationPrefs.fromMap({'postComment': 'no'}),
          const NotificationPrefs());
      expect(NotificationPrefs.fromMap({'voteEnd': false}),
          const NotificationPrefs(voteEnd: false));
    });

    test('저장은 사용자 문서의 다른 필드를 건드리지 않는다', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore
          .collection('users')
          .doc('u1')
          .set({'displayName': '춘배', 'crackers': 30});
      final repo = NotificationPrefsRepository(firestore: firestore);
      await repo.save('u1', const NotificationPrefs(commentReply: false));

      final data =
          (await firestore.collection('users').doc('u1').get()).data()!;
      expect(data['displayName'], '춘배');
      expect(data['crackers'], 30);
      // 키 이름은 서버 함수(notificationPrefs.ts)와 같다.
      expect(data['notificationPrefs'],
          {'postComment': true, 'commentReply': false, 'voteEnd': true});
      expect(
          await repo.load('u1'), const NotificationPrefs(commentReply: false));
    });
  });

  group('알림 설정 화면', () {
    late FakeFirebaseFirestore firestore;
    late _MockUserProvider user;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      user = _MockUserProvider();
      when(user.currentUser).thenReturn(const AppUser(id: 'u1'));
    });

    Future<void> open(WidgetTester tester, {bool? osAllowed = true}) async {
      await tester.pumpWidget(ChangeNotifierProvider<UserProvider>.value(
        value: user,
        child: MaterialApp(
          home: NotificationSettingsScreen(
            repository: NotificationPrefsRepository(firestore: firestore),
            osPushAllowed: () async => osAllowed,
          ),
        ),
      ));
      await tester.pump();
      await tester.pump();
    }

    bool switchValue(WidgetTester tester, String key) => tester
        .widget<SwitchListTile>(find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(SwitchListTile)))
        .value;

    testWidgets('처음에는 세 가지 모두 켜져 있고, 끄면 바로 저장된다', (tester) async {
      await open(tester);
      expect(switchValue(tester, 'pref-post-comment'), isTrue);
      expect(switchValue(tester, 'pref-comment-reply'), isTrue);
      expect(switchValue(tester, 'pref-vote-end'), isTrue);

      await tester.tap(find.byKey(const ValueKey('pref-vote-end')));
      await tester.pump();
      expect(switchValue(tester, 'pref-vote-end'), isFalse);
      final saved = (await firestore.collection('users').doc('u1').get())
          .data()!['notificationPrefs'];
      expect(saved['voteEnd'], isFalse);
      expect(find.textContaining('알림 목록(종 아이콘)에는 그대로'), findsOneWidget);
    });

    testWidgets('저장된 값을 보여준다', (tester) async {
      await firestore.collection('users').doc('u1').set({
        'notificationPrefs': {'postComment': false}
      });
      await open(tester);
      expect(switchValue(tester, 'pref-post-comment'), isFalse);
      expect(switchValue(tester, 'pref-comment-reply'), isTrue);
    });

    testWidgets('휴대폰 설정에서 알림이 꺼져 있으면 알려주고 바로 갈 길을 준다',
        (tester) async {
      await open(tester, osAllowed: false);
      expect(find.byKey(const ValueKey('os-push-off')), findsOneWidget);
      // 어디로 가야 하는지 적어만 두면 찾아가기 멀다(5차).
      expect(find.byKey(const ValueKey('open-os-settings')), findsOneWidget);
    });

    testWidgets('알림이 켜져 있으면 설정 열기 버튼도 없다', (tester) async {
      await open(tester, osAllowed: true);
      expect(find.byKey(const ValueKey('open-os-settings')), findsNothing);
    });

    testWidgets('휴대폰 허용 여부를 모르면 안내하지 않는다', (tester) async {
      await open(tester, osAllowed: null);
      expect(find.byKey(const ValueKey('os-push-off')), findsNothing);
    });
  });
}
