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
}
