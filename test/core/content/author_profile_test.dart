// 올린 사람 프로필 사진 읽기(5차 338, 사용자 요청).

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/author_profile.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    AuthorProfiles.resetForTest();
    firestore = FakeFirebaseFirestore();
    AuthorProfiles.firestore = firestore;
  });

  tearDown(AuthorProfiles.resetForTest);

  test('사진이 있으면 주소를 돌려주고 두 번째부터는 들고 있던 것을 쓴다', () async {
    await firestore
        .collection('users')
        .doc('mina')
        .set({'photoUrl': 'https://example.com/mina.jpg'});

    expect(
        await AuthorProfiles.photoUrl('mina'), 'https://example.com/mina.jpg');
    expect(AuthorProfiles.cached('mina'), 'https://example.com/mina.jpg');

    // 서버에서 지워도 들고 있던 값을 쓴다(앱을 켜 둔 동안).
    await firestore.collection('users').doc('mina').delete();
    expect(
        await AuthorProfiles.photoUrl('mina'), 'https://example.com/mina.jpg');
  });

  test('사진이 없거나 사람이 없으면 null', () async {
    await firestore.collection('users').doc('noPhoto').set({'photoUrl': ''});
    expect(await AuthorProfiles.photoUrl('noPhoto'), isNull);
    expect(await AuthorProfiles.photoUrl('없는사람'), isNull);
  });

  test('uid가 비어 있으면 읽지 않는다', () async {
    expect(await AuthorProfiles.photoUrl('  '), isNull);
    expect(AuthorProfiles.cached(''), isNull);
  });
}
