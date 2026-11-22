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
    // FirebaseException 갈래와 나머지 갈래 두 곳 모두에 있어야 한다.
    expect(calls.length, 2);
  });

  // Dart의 Error는 Exception이 아니다(5차 563). 'on Exception'으로만
  // 받으면 StateError·TypeError가 났을 때 되돌리기를 건너뛰고, 올라간
  // 파일이 아무도 가리키지 않는 채 용량만 먹는다. 이 블록 안에는
  // StateError를 던지는 자리와 Firestore 값을 캐스팅하는 자리가 있다.
  test('Error도 받아서 되돌린다', () {
    final upload = source.substring(
      source.indexOf('server-upload start'),
      source.indexOf('Future<void> _discardUploadedObjects'),
    );
    expect(upload.contains('} on Exception catch'), isFalse,
        reason: 'Exception만 받으면 Error에서 새어 나간다');
    expect(upload.contains('} catch (e, st) {'), isTrue);
  });

  test('되돌리기는 path로 지운다', () {
    expect(
      source.contains('UserFileStorage.instance.deleteQuietly(path: key)'),
      isTrue,
    );
  });
}
