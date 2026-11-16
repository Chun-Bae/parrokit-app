// 올린 사람 프로필 사진 위젯(5차 338).

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/author_profile.dart';
import 'package:parrokit/core/shared/widgets/author_avatar.dart';

Widget app(String authorId) =>
    MaterialApp(home: Scaffold(body: AuthorAvatar(authorId: authorId)));

void main() {
  setUp(() {
    AuthorProfiles.resetForTest();
    AuthorProfiles.firestore = FakeFirebaseFirestore();
  });

  tearDown(AuthorProfiles.resetForTest);

  testWidgets('사진이 없으면 사람 아이콘을 보여 준다', (tester) async {
    await tester.pumpWidget(app('mina'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    expect(
        tester.widget<CircleAvatar>(find.byType(CircleAvatar)).foregroundImage,
        isNull);
  });

  testWidgets('사진이 있으면 읽어 오고, 못 내려받으면 아이콘으로 돌아간다', (tester) async {
    await (AuthorProfiles.firestore!)
        .collection('users')
        .doc('mina')
        .set({'photoUrl': 'https://example.com/mina.jpg'});

    await tester.pumpWidget(app('mina'));
    await tester.pumpAndSettle();

    // 위젯이 사진 주소를 읽어 왔다.
    expect(AuthorProfiles.cached('mina'), 'https://example.com/mina.jpg');
    // 테스트에서는 내려받기가 실패한다(400). 그때는 사람 아이콘만 남는다.
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    expect(
        tester.widget<CircleAvatar>(find.byType(CircleAvatar)).foregroundImage,
        isNull);
  });

  testWidgets('프로필 사진을 바꾸면 그 자리도 바로 바뀐다', (tester) async {
    await tester.pumpWidget(app('me'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);

    // 사용자가 프로필 사진을 바꾸면 UserProvider가 이렇게 알려 준다.
    AuthorProfiles.remember('me', 'https://example.com/new.jpg');
    await tester.pump();

    expect(
        (tester.widget<CircleAvatar>(find.byType(CircleAvatar)).foregroundImage
                as NetworkImage?)
            ?.url,
        'https://example.com/new.jpg');
  });

  test('사진을 지우면 들고 있던 값도 비운다', () {
    AuthorProfiles.remember('me', 'https://example.com/a.jpg');
    expect(AuthorProfiles.cached('me'), 'https://example.com/a.jpg');
    AuthorProfiles.remember('me', null);
    expect(AuthorProfiles.cached('me'), isNull);

    AuthorProfiles.remember('other', 'https://example.com/b.jpg');
    final before = AuthorProfiles.revision.value;
    AuthorProfiles.forget('other');
    expect(AuthorProfiles.cached('other'), isNull);
    expect(AuthorProfiles.revision.value, before + 1);
  });
}
