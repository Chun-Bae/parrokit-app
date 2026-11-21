// 서버로 옮기다 엎어지면 이번에 올린 R2 파일을 되돌리는지 지킨다(5차 510).
//
// moveClipToServer는 Drift DB와 Firebase가 다 있어야 돌아서 통째로 부르는
// 테스트를 두기 어렵다. 대신 되돌리기 호출이 사라지지 않았는지만 본다.
// 영상만 올라가고 썸네일이나 Firestore 쓰기에서 실패하면, r2FinishUpload가
// 이미 용량에 더해 둔 파일이 아무도 가리키지 않는 채 남는다. 화면에는
// 안 보이면서 구독 용량만 먹고, 다시 누를 때마다 하나씩 쌓인다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/core/domain/collection_clip/data/repositories/'
    'clip_migration_repository_impl.dart',
  ).readAsStringSync();

  test('올린 키를 모아 둔다', () {
    expect(source.contains('uploadedKeys.add(result.path)'), isTrue);
  });

  test('실패하면 올린 파일을 지운다', () {
    final calls = '_discardUploadedObjects(uploadedKeys'.allMatches(source);
    // FirebaseException 갈래와 Exception 갈래 두 곳 모두에 있어야 한다.
    expect(calls.length, 2);
  });

  test('되돌리기는 path로 지운다', () {
    expect(
      source.contains('UserFileStorage.instance.deleteQuietly(path: key)'),
      isTrue,
    );
  });
}
