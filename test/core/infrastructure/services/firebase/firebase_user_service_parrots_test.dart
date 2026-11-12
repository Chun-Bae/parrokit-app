// 패롯 증감이 서버 값 기준이고 크래커를 건드리지 않는지 본다.
//
// 전에는 앱에 캐시된 패롯·크래커를 서버에 통째로 덮어써서, 캐시가 옛 값이면
// 서버에서 생긴 크래커 변화(질문 등록 차감, 답변 채택 보상)가 지워졌다.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/infrastructure/services/firebase/firebase_user_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirebaseUserService service;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    service = FirebaseUserService(firestore: firestore);
    await firestore.collection('users').doc('u').set({
      'parrots': 10,
      'crackers': 1500,
    });
  });

  test('서버에 있는 패롯에 더하고 크래커는 서버 값 그대로 돌려준다', () async {
    // 답변 채택으로 서버에서 크래커가 올라간 상황. 앱 캐시는 이걸 모른다.
    await firestore.collection('users').doc('u').update({'crackers': 1550});

    final result = await service.addParrots(uid: 'u', delta: 3);

    expect(result.parrots, 13);
    expect(result.crackers, 1550);
    final data = (await firestore.collection('users').doc('u').get()).data()!;
    expect(data['parrots'], 13);
    expect(data['crackers'], 1550);
  });

  test('차감도 서버 값 기준이다', () async {
    final result = await service.addParrots(uid: 'u', delta: -4);

    expect(result.parrots, 6);
    expect(result.crackers, 1500);
  });
}
