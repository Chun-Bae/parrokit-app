// 서버를 부르는 모든 자리에 기다릴 시간이 정해져 있다(5차 447).
//
// 같은 결함이 세 번 났다. 목소리 목록(395), 챗봇 사용량(429), 뜻 채우기
// 횟수(446). 모두 응답이 안 오면 돌아가는 표시가 영영 남았고, 사용자는
// 화면에 갇혔다. 세 번을 고친 뒤 lib 전체를 훑어 16곳을 막았으므로,
// 앞으로 새로 생기는 자리는 이 테스트가 잡는다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/utils/remote_call_timeout.dart';

/// `.call(...)`의 닫는 괄호 위치를 찾는다(제네릭과 중첩 괄호가 있다).
final _callPattern = RegExp(r'(?<!\?)\.call\s*(<.*?>)?\s*\(');

int _closingParen(String source, int openAfter) {
  var i = openAfter;
  var depth = 1;
  while (i < source.length && depth > 0) {
    if (source[i] == '(') depth++;
    if (source[i] == ')') depth--;
    i++;
  }
  return i;
}

List<String> _callsWithoutWait() {
  final found = <String>[];
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final source = entity.readAsStringSync();
    if (!source.contains('httpsCallable')) continue;
    // httpsCallable(options: ...)로 시간을 정하는 것도 인정한다.
    final optionTimeout =
        source.replaceAll(' ', '').contains('HttpsCallableOptions(timeout:');
    for (final match in _callPattern.allMatches(source)) {
      final end = _closingParen(source, match.end);
      final after = source.substring(end, (end + 40).clamp(0, source.length));
      if (after.contains('.timeout(')) continue;
      if (optionTimeout) continue;
      final line = source.substring(0, match.start).split('\n').length;
      found.add('${entity.path}:$line');
    }
  }
  return found;
}

void main() {
  test('서버 호출에 기다릴 시간이 빠진 자리가 없다', () {
    expect(
      _callsWithoutWait(),
      isEmpty,
      reason: '.timeout(shortCallTimeout) 또는 .timeout(generateCallTimeout)을 붙인다',
    );
  });

  test('묻는 일은 짧게, 만드는 일은 길게 기다린다', () {
    expect(shortCallTimeout, lessThan(generateCallTimeout));
    // 너무 짧으면 멀쩡히 되던 것도 실패로 보인다.
    expect(shortCallTimeout.inSeconds, greaterThanOrEqualTo(10));
  });
}
