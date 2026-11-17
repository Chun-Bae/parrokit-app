// 화면에서 무언가를 적거나 고르라고 할 때 쓰는 말을 하나로 맞춘다(5차 418).
//
// 앱은 '적어 주세요'와 '골라 주세요'를 쓴다. 그런데 커뮤니티 글쓰기는
// '제목을 입력해 주세요.', 자막 만들기는 '영상 파일을 먼저 선택해 주세요.',
// 언어 고르기는 '... 언어를 선택하세요.'처럼 화면마다 달랐다.
// 같은 뜻을 세 가지 말로 적으면 어느 것이 앱의 말인지 알 수 없다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 주석과 개발자용 예외는 빼고, 화면에 보이는 글만 남긴다.
List<String> _uiLines(File file) => file
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .toList();

Iterable<File> _dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

void main() {
  test("화면 글에 '입력해/선택해 주세요'와 '입력하세요/선택하세요'가 없다", () {
    const banned = [
      '입력해 주세요',
      '선택해 주세요',
      '입력해주세요',
      '선택해주세요',
      '입력하세요',
      '선택하세요',
    ];
    final offenders = <String>[];
    for (final file in _dartFiles('lib')) {
      for (final line in _uiLines(file)) {
        for (final word in banned) {
          if (line.contains("'") && line.contains(word)) {
            offenders.add('${file.path}: $word');
          }
        }
      }
    }
    expect(offenders, isEmpty,
        reason: "'적어 주세요' 또는 '골라 주세요'를 쓴다\n${offenders.join('\n')}");
  });

  test('영상을 고르라는 말은 ClipValidator 한 곳에서 나온다', () {
    final validator = File(
            'lib/features/content-studio/captioning/domain/validators/clip_validator.dart')
        .readAsStringSync();
    expect(validator, contains("noFileMessage = '영상을 먼저 골라 주세요.'"));

    // 전에는 provider가 같은 말을 두 가지로 손수 적었다
    // ('먼저 영상 파일을 선택해 주세요.' / '영상 파일을 먼저 선택해 주세요.').
    final provider = File(
            'lib/features/content-studio/captioning/presentation/providers/captioning_provider.dart')
        .readAsStringSync();
    expect(provider, isNot(contains("showToast('영상 파일을")));
    expect(provider, isNot(contains("showToast('먼저 영상")));
    expect('ClipValidator.noFileMessage'.allMatches(provider).length,
        greaterThanOrEqualTo(2));
  });

  test('닉네임을 적으라는 말은 nickname_rule 한 곳에서 나온다', () {
    final block = File(
            'lib/features/community/block/presentation/providers/block_provider.dart')
        .readAsStringSync();
    expect(block, contains('nicknameNeededMessage'));
    expect(block, isNot(contains("'닉네임을 입력")));
  });

  test('안 써도 되는 칸은 비워도 된다고 적는다', () {
    // 칸 이름이 '발음 (선택)'이었다. 바로 아래 안내는 '발음은 비워도 돼요'라
    // 적혀 있어, 같은 것을 두 말로 불렀다(5차 420).
    final offenders = <String>[];
    for (final file in _dartFiles('lib')) {
      for (final line in _uiLines(file)) {
        if (line.contains("'") && line.contains('(선택)')) {
          offenders.add(file.path);
        }
      }
    }
    expect(offenders, isEmpty,
        reason: "'(비워도 돼요)'로 적는다\n${offenders.join('\n')}");
  });

  test("무엇을 고르는 시트·단추 이름이 '… 선택'이 아니라 '… 고르기'다", () {
    // 시트 제목만 '목소리 선택'·'언어 선택'처럼 명사형이라, 앱의 다른 곳
    // ('폴더를 골라 주세요', '백업할 것을 하나는 골라 주세요')과 말이 갈렸다(5차 419).
    //
    // 여러 개를 고르는 모드('전체 선택', '선택 모드')와 안 써도 되는 칸을
    // 가리키는 '(선택)'은 뜻이 달라 여기서 다루지 않는다.
    const allowed = [
      '전체 선택',
      '선택 모드',
      '선택 닫기',
      '선택한',
      '개 선택',
      '(선택)',
    ];
    final offenders = <String>[];
    for (final file in _dartFiles('lib')) {
      for (final line in _uiLines(file)) {
        final match = RegExp(r"'[^'\n]*선택'").firstMatch(line);
        if (match == null) continue;
        final found = match.group(0)!;
        if (allowed.any(found.contains)) continue;
        offenders.add('${file.path}: $found');
      }
    }
    expect(offenders, isEmpty,
        reason: "'… 고르기'로 적는다\n${offenders.join('\n')}");
  });
}
