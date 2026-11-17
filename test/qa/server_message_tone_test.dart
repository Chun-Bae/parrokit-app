// 서버가 보내는 안내도 앱 말투를 쓴다(5차 438).
//
// 챗봇은 서버가 보낸 글을 말풍선에 **그대로** 띄우고, 자동 자막·질문 화면도
// 서버 글을 그대로 보여 준다. 그래서 서버에 '~습니다'가 남아 있으면 앱이
// 아무리 말을 맞춰도 사용자에게는 어긋난 글이 보인다.
//
// 428에서 앱 쪽은 '사용자가 할 수 없는 일을 시키지 않는다'로 고쳤는데,
// 서버는 'OpenAI 요청 한도를 초과했습니다'를 그대로 보내고 있었다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Iterable<File> _serverFiles() => Directory('functions/src')
    .listSync()
    .whereType<File>()
    .where((f) => f.path.endsWith('.ts'));

/// 주석을 뺀, 서버가 문자열로 적은 글만.
List<String> _quoted(File file) {
  final out = <String>[];
  for (final line in file.readAsLinesSync()) {
    final t = line.trimLeft();
    if (t.startsWith('//') || t.startsWith('*') || t.startsWith('/*')) continue;
    for (final m in RegExp(r'"[^"\n]*"').allMatches(line)) {
      final text = m.group(0)!;
      if (RegExp('[가-힣]').hasMatch(text)) out.add('${file.path}: $text');
    }
  }
  return out;
}

void main() {
  test("서버 안내에 '~습니다' 말투가 없다", () {
    final offenders = [
      for (final f in _serverFiles())
        ..._quoted(f).where((t) => t.contains('습니다')),
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('서버가 사용자에게 할 수 없는 일을 시키지 않는다', () {
    const cannotDo = ['OpenAI', '할당량', '요청 한도를 초과'];
    final offenders = [
      for (final f in _serverFiles())
        ..._quoted(f).where((t) => cannotDo.any(t.contains)),
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test("서버도 '잠시 후' 대신 '잠시 뒤'를 쓴다", () {
    final offenders = [
      for (final f in _serverFiles())
        ..._quoted(f).where((t) => t.contains('잠시 후')),
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
