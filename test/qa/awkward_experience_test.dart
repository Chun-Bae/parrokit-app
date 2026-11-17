// 사람이 보기 어색한 경험을 찾아내는 테스트(5차 411, 사용자 요청).
//
// 이번 사용자 신고 셋은 모두 '코드는 도는데 사람이 보기 이상한' 것이었다.
//   - 저장하지도 않은 남의 문장을 들었더니 내 친밀도가 올랐다
//   - 카드가 눌러도 아무 일이 없다
//   - 파일 이름에 '${DateTime.now()...}'가 그대로 찍힌다
// 같은 꼴을 자동으로 잡는다. 화면 글과 코드를 훑어 '사람이 보면 바로
// 이상한' 자국만 본다. 오탐이 나면 여기 규칙을 고친다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Iterable<File> _dartFiles(String dir) sync* {
  for (final e in Directory(dir).listSync(recursive: true)) {
    if (e is File && e.path.endsWith('.dart')) yield e;
  }
}

/// 주석을 뺀 줄만.
List<String> _codeLines(File f) => f
    .readAsLinesSync()
    .where((l) => !l.trimLeft().startsWith('//'))
    .toList();

/// 화면에 그리는 작은따옴표 글.
Iterable<String> _uiStrings(File f) sync* {
  for (final line in _codeLines(f)) {
    if (line.contains('AppLogger')) continue;
    for (final m in RegExp(r"'([^']*)'").allMatches(line)) {
      yield m.group(1)!;
    }
  }
}

void main() {
  test('화면 글에 코드가 새어 나오지 않는다', () {
    // 작은따옴표 안에서 \$를 escape 하면 '${...}'가 글자 그대로 보인다.
    final offenders = <String>[];
    for (final f in _dartFiles('lib')) {
      for (final line in _codeLines(f)) {
        // '\${...}'만 잡는다. 'US\$0.99'처럼 달러 기호를 적는 것은 맞다.
        if (line.contains(r'\${')) {
          offenders.add('${f.path}: ${line.trim()}');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: "작은따옴표 글 안의 \\\$는 화면에 그대로 찍힌다:\n"
            "${offenders.join('\n')}");
  });

  test('화면 글이 null·Instance of 같은 내부 값을 보여 주지 않는다', () {
    final offenders = <String>[];
    for (final f in _dartFiles('lib')) {
      for (final text in _uiStrings(f)) {
        // 'Exception: '은 예외 접두어를 떼는 코드에도 쓰이고, 'null'은
        // 보간 속 조건식에도 들어간다. 사람 눈에 바로 보이는 자국만 본다.
        if (text.contains('Instance of')) offenders.add('${f.path}: $text');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('누를 수 있어 보이는 카드에는 할 일이 있다', () {
    // 홈 공유 문장 카드가 눌러도 아무 일이 없었다(5차 410).
    // 가로로 넘기는 카드 목록은 누르면 무언가 열려야 한다.
    const cards = [
      'lib/features/home/dashboard/presentation/widgets/trending_sentences_preview.dart',
      'lib/features/collection/shell/presentation/widgets/sentence_collection_preview.dart',
    ];
    for (final path in cards) {
      final code = _codeLines(File(path)).join('\n');
      expect(code, contains('onTap'), reason: path);
    }
  });

  test('기록을 쌓는 곳은 내 것인지 먼저 따진다', () {
    // 남의 문장을 들어도 내 친밀도가 올랐다(5차 410).
    final code = _codeLines(File(
            'lib/features/collection/shell/presentation/widgets/sentence_collection_preview.dart'))
        .join('\n');
    for (final call in [
      'SentenceActivityStore.incrementListen(',
      'SentenceActivityStore.incrementPractice(',
    ]) {
      final at = code.indexOf(call);
      if (at < 0) continue;
      final before = code.substring(at < 400 ? 0 : at - 400, at);
      expect(before, contains('widget.saved'),
          reason: '$call 앞에 내 문장인지 따지는 자리가 없다');
    }
  });

  test('단추 이름이 무엇을 하는지 말한다', () {
    // '저장'·'생성'처럼 한 낱말만 있는 이름은 어디에 무엇을 하는지 모른다.
    const vague = ['저장', '생성', '확인', '완료', '적용'];
    final offenders = <String>[];
    for (final f in _dartFiles('lib/features')) {
      for (final line in _codeLines(f)) {
        if (!line.contains('label: const Text(')) continue;
        for (final word in vague) {
          if (line.contains("label: const Text('$word')")) {
            offenders.add('${f.path}: $word');
          }
        }
      }
    }
    expect(offenders, isEmpty,
        reason: "무엇을 하는지 적는다('저장' → 'mp3 파일로 내려받기'):\n"
            "${offenders.join('\n')}");
  });

  test('같은 뜻을 두 말로 쓰지 않는다', () {
    // '잠시 후'와 '잠시 뒤'가 섞여 있었다(5차 414). 같은 문장인데 화면마다
    // 달랐다('지우지 못했어요. 잠시 후/뒤 다시 해 주세요.').
    final offenders = <String>[];
    for (final f in _dartFiles('lib')) {
      for (final line in _codeLines(f)) {
        if (line.contains('잠시 후')) {
          offenders.add('${f.path}: ${line.trim()}');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: "앱은 '잠시 뒤'로 적는다:\n${offenders.join('\n')}");
  });
}
