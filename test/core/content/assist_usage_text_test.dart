// 뜻 채우기 하루 한도 안내를 한 곳에서 꺼낸다(5차 445).
//
// 문장 추가 화면과 단어 상세가 같은 말을 각자 적고 있었다. 단어 쪽만
// 함수로 빼 두어서, 한쪽을 다듬으면 갈라질 자리였다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/assist_usage_text.dart';

const _home = 'lib/core/content/assist_usage_text.dart';

Iterable<File> _dartFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

void main() {
  test('쓴 횟수인지 알 수 있게 적는다', () {
    expect(assistUsageLabel(used: 0, limit: 3), '오늘 0/3회 사용');
    expect(assistUsageLabel(used: null, limit: 3), isNull);
    expect(assistUsageLabel(used: 1, limit: null), isNull);
  });

  test('두 화면이 같은 글귀를 쓴다', () {
    final offenders = <String>[];
    for (final file in _dartFiles()) {
      if (file.path.endsWith(_home)) continue;
      final code = file
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      for (final text in ['오늘 \$used/\$limit회 사용', assistUsageLoadingLabel]) {
        if (code.contains("'$text'")) offenders.add('${file.path}: $text');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
