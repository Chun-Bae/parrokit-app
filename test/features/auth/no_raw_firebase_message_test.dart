import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 로그인·가입·비밀번호 찾기 화면이 Firebase 영어 원문(e.message)을 토스트에
/// 다시 넣지 않게 지킨다(5차). 안내는 userErrorMessage로 고른다.
void main() {
  test('인증 화면 토스트에 e.message를 그대로 넣지 않는다', () {
    final files = Directory('lib/features/auth')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    final offenders = <String>[];
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (RegExp(r'showToast\([^)]*\$\{?e\.message').hasMatch(lines[i])) {
          offenders.add('${file.path}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
