// 새 언어 안내는 고르개 한 곳에서만 한다(5차 481).
//
// 문장 설정에는 고르개 바로 아래에 자물쇠와 '그 외 언어는 준비 중'이
// 붙어 있었다. 고르개는 영어·일본어·중국어를 다 내주는데 그 밑에서
// 잠겼다고 하니 어긋나 보였고, 고르개 안에 이미 '새 언어는 이 목록에
// 계속 추가할 수 있어요.'가 있어 같은 말이 두 번이었다. 고르개를 쓰는
// 다른 네 화면에는 이 줄이 없었다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _noticeOwner = 'lib/core/shared/widgets/learning_language_picker.dart';

Iterable<File> _dartFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

String _code(File file) => file
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('언어가 잠겨 있다고 말하는 화면이 없다', () {
    final offenders = <String>[];
    for (final file in _dartFiles()) {
      if (_code(file).contains('그 외 언어는 준비 중')) offenders.add(file.path);
    }
    expect(offenders, isEmpty,
        reason: '고르개가 내주는 언어를 두고 잠겼다고 적지 않는다');
  });

  test('새 언어 안내는 고르개에만 있다', () {
    final owners = <String>[];
    for (final file in _dartFiles()) {
      if (_code(file).contains('새 언어는 이 목록에 계속 추가할 수 있어요.')) {
        owners.add(file.path.replaceAll(r'\', '/'));
      }
    }
    expect(owners, [_noticeOwner]);
  });
}
