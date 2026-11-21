// 프로필 사진을 바꿀 때 옛 사진 지우기를 기다리지 않는다(5차 511).
//
// R2로 옮긴 뒤로 올리기도 지우기도 Cloud Function이라, 찬 함수가 깨어나는
// 20초가 두 번 붙었다. 사진 한 장 바꾸는 데 전체 화면 스피너로 1분을
// 세워 뒀다. 지우기 결과는 화면에 쓰이지 않고 deleteQuietly는 던지지도
// 않으니 기다릴 까닭이 없다.
//
// 저장 흐름은 Firebase와 go_router가 다 있어야 돌아서 통째로 부르기
// 어렵다. 기다리지 않는 호출이 다시 await로 돌아가지 않았는지만 본다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/features/settings/more/presentation/profile_edit_screen.dart',
  ).readAsStringSync();

  test('옛 사진 지우기는 기다리지 않는다', () {
    expect(
      source.contains(
        'unawaited(UserFileStorage.instance.deleteQuietly(url: previousPhotoUrl))',
      ),
      isTrue,
    );
  });

  test('새 사진 올리기는 기다린다', () {
    // 올리기까지 띄워 보내면 주소 없이 저장된다.
    expect(source.contains('await UserFileStorage.instance.uploadFile('), isTrue);
  });
}
