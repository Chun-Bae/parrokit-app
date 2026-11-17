// 문장 공유·가져오기 결과 안내를 한 곳에서만 적는다(5차 421).
//
// 네 자리(보관함 문장 목록, 문장 상세 시트, 공유 시트, 홈 둘러보기 줄)가
// 같은 말을 각자 적고 있었다. 가져오기 안내는 '내 문장에 저장했어요'와
// '추가했어요'로 갈렸고, 하루 한도 안내는 예외의 toString()을 글 앞에
// 붙여 만들었다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/sentence_share_text.dart';

const _home = 'lib/core/content/sentence_share_text.dart';

Iterable<File> _dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

List<String> _uiLines(File file) => file
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .toList();

void main() {
  test('하루 한도 안내는 예외 글을 끌어다 쓰지 않는다', () {
    expect(sentenceShareLimitMessage(10),
        '하루에 10개까지 공유할 수 있어요. 내일 다시 공유해 주세요.');

    for (final file in _dartFiles('lib')) {
      for (final line in _uiLines(file)) {
        expect(line, isNot(contains(r'$e 내일')), reason: file.path);
      }
    }
  });

  test('공유·가져오기 안내를 다른 파일이 손으로 적지 않는다', () {
    const texts = [
      sentenceSharedMessage,
      sentenceShareCanceledMessage,
      sentenceSavedToMineMessage,
      sentenceAlreadySavedMessage,
      sentenceRemovedFromMineMessage,
      sentenceIsMineMessage,
    ];
    final offenders = <String>[];
    for (final file in _dartFiles('lib')) {
      if (file.path.endsWith(_home)) continue;
      for (final line in _uiLines(file)) {
        for (final text in texts) {
          if (line.contains("'$text'")) offenders.add('${file.path}: $text');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: '$_home에서 꺼내 쓴다\n${offenders.join('\n')}');
  });

  test("가져오기 안내가 '추가했어요'로 갈리지 않는다", () {
    final offenders = <String>[];
    for (final file in _dartFiles('lib')) {
      for (final line in _uiLines(file)) {
        if (line.contains("'추가했어요. 홈 앵무새가 말해줘요.'")) {
          offenders.add(file.path);
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('저장 단추 설명이 지금 상태에 맞는다(5차 426)', () {
    // 보관함 둘러보기 카드는 이미 저장한 뒤에도 '내 문장에 저장'이라고
    // 적혀 있었다. 누르면 빼는데 저장이라고 말했다.
    expect(saveToMineTooltip(saved: false), '내 문장에 저장');
    expect(saveToMineTooltip(saved: true), '내 문장에서 빼기');

    for (final path in [
      'lib/features/collection/shell/presentation/widgets/sentence_collection_preview.dart',
      'lib/features/home/dashboard/presentation/widgets/trending_sentences_preview.dart',
    ]) {
      final code = File(path)
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(code, contains('saveToMineTooltip(saved:'), reason: path);
      expect(code, isNot(contains("tooltip: '내 문장에 저장'")), reason: path);
    }
  });

  test('좋아요·공유 단추 글을 다른 파일이 손으로 적지 않는다', () {
    const texts = [
      likeNeedsLoginMessage,
      likeFailedMessage,
      shareMySentenceLabel,
    ];
    final offenders = <String>[];
    for (final file in _dartFiles('lib')) {
      if (file.path.endsWith(_home)) continue;
      for (final line in _uiLines(file)) {
        for (final text in texts) {
          if (line.contains("'$text'")) offenders.add('${file.path}: $text');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: '$_home에서 꺼내 쓴다\n${offenders.join('\n')}');
  });
}
