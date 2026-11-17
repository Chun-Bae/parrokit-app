// 자주 쓰는 실패 안내는 한 곳에서만 적는다(5차 417).
//
// 같은 문장이 화면마다 손으로 적혀 있었다('저장하지 못했어요. 다시 시도해
// 주세요.' 세 파일, '처리하지 못했어요…' 세 파일, '불러오지 못했어요.'
// 세 파일). 한 곳만 다듬으면 나머지는 예전 말로 남는다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/utils/action_failed_text.dart';

Iterable<File> _dartFiles() sync* {
  for (final e in Directory('lib').listSync(recursive: true)) {
    if (e is File && e.path.endsWith('.dart')) yield e;
  }
}

/// 그 글을 손으로 적은 파일(글귀를 모아 둔 파일은 뺀다).
List<String> _handWritten(String text) => _dartFiles()
    .where((f) => !f.path.endsWith('action_failed_text.dart'))
    .where((f) => f
        .readAsLinesSync()
        .where((l) => !l.trimLeft().startsWith('//'))
        .any((l) => l.contains("'$text'")))
    .map((f) => f.path)
    .toList();

void main() {
  test('실패 안내를 화면에서 또 적지 않는다', () {
    for (final text in [
      saveFailedMessage,
      sentenceSaveFailedMessage,
      actionFailedMessage,
      loadFailedMessage,
    ]) {
      expect(_handWritten(text), isEmpty, reason: text);
    }
  });

  test('지우기 실패는 커뮤니티 글귀와 같은 말이다', () {
    final community = File(
            'lib/features/community/shared/presentation/community_delete_text.dart')
        .readAsStringSync();
    expect(community, contains(deleteFailedShortMessage));
    // 클립 쪽에서 손으로 적던 같은 문장.
    expect(
        _handWritten(deleteFailedShortMessage)
            .where((p) => !p.endsWith('community_delete_text.dart')),
        isEmpty);
  });
}
