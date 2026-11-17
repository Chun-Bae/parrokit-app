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

  test('옮기기·지우기 진행 막대의 끝말이 하나다(5차 424)', () {
    // 같은 오버레이 안에서 '잠시 뒤 다시 해 주세요'와 '잠시 뒤 다시 시도해
    // 주세요'가 섞여 있었다.
    for (final text in [
      deleteInterruptedMessage,
      moveInterruptedMessage,
      serverSaveFailedMessage,
      driveSaveFailedMessage,
      deviceMoveFailedMessage,
      deleteFailedMessageFor('폴더'),
      deleteFailedMessageFor('그룹'),
    ]) {
      expect(text, endsWith(retryLaterSuffix), reason: text);
      expect(text, isNot(contains('다시 시도해')), reason: text);
    }

    final provider = File('lib/core/state/provider/clip_provider.dart')
        .readAsLinesSync()
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    expect(provider, isNot(contains('잠시 뒤 다시 시도해 주세요')));
    expect(provider, isNot(contains('실패했어요')));
  });

  test('무엇을 지우지 못했는지 조사를 받침에 맞춘다', () {
    expect(deleteFailedMessageFor('폴더'), startsWith('폴더를 지우지 못했어요.'));
    expect(deleteFailedMessageFor('그룹'), startsWith('그룹을 지우지 못했어요.'));
  });

  test('여러 화면이 함께 쓰는 짧은 안내도 한 곳에서 꺼낸다(5차 444)', () {
    // 넷 다 두 자리에 손으로 적혀 있었다.
    for (final text in [
      settingsSaveFailedMessage,
      noChangesMessage,
      sentenceNeededMessage,
      comingSoonMessage,
    ]) {
      expect(_handWritten(text), isEmpty, reason: text);
    }
  });
}
