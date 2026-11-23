// 질문을 올릴 때 앱이 잔액을 덮어쓰지 않는다(5차 568).
//
// 서버(functions/src/questions.ts)가 크래커를 깎는다. 앱이 또 쓰면
// 서버 호출 **전에** 읽은 옛 값으로 사용자 문서를 통째로 덮어써,
// 그 사이 들어온 연습 보상·광고 보상이 날아간다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _code(String path) => File(path)
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  const screen =
      'lib/features/community/question/presentation/question_write_screen.dart';

  test('질문을 올린 뒤 앱이 잔액을 쓰지 않는다', () {
    final code = _code(screen);
    expect(code.contains('updateUser('), isFalse);
    expect(code.contains('addCrackers('), isFalse);
  });

  // 모자란지 보는 것은 그대로 둔다. 서버가 막기 전에 미리 알려 준다.
  test('크래커가 모자라면 미리 막는다', () {
    expect(_code(screen), contains('user.crackers < _rewardCrackers'));
  });

  test('서버가 크래커를 깎는다', () {
    final server = File('functions/src/questions.ts').readAsStringSync();
    expect(server, contains('crackers: -reward'));
  });
}
