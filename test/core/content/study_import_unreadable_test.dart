// 읽을 수 없는 파일과 이미 다 있는 파일을 가른다(5차).
//
// 더보기 > 문장·단어 주고받기 > 파일에서 불러오기는 어떤 .json이든 고를 수
// 있다. 전에는 importStudyData가 **못 읽어도 0을 돌려줘서**, 엉뚱한 파일을
// 골랐을 때도 '새로 들어온 문장과 단어는 없어요.'가 떴다. 사용자 눈에는
// 이미 다 들어 있는 파일을 고른 것과 똑같이 보여서, 잘못 골랐다는 것을
// 모르고 넘어간다.
//
// 시뮬레이터에서 내보낸 파일을 그대로 다시 불러와 찾았다. 그때는 0개가
// 맞는 말이었는데, 그 말이 **엉뚱한 파일에도 똑같이** 나온다는 것을 코드로
// 확인했다. 백업 쪽은 같은 자리에서 이미 'backupNothingRestoredMessage'로
// 가르고 있다 - 두 흐름이 다르게 굴면 안 된다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/study_data_transfer.dart';

Future<Object?> _errorOf(Future<void> Function() run) async {
  try {
    await run();
    return null;
  } catch (e) {
    return e;
  }
}

void main() {
  group('못 읽는 파일은 못 읽었다고 한다', () {
    test('JSON이 아니면 던진다', () async {
      final e = await _errorOf(() => importStudyData('uid', '이건 JSON이 아니다'));
      expect(e, isNotNull);
      expect(e.toString(), contains(studyFileUnreadableMessage));
    });

    test('모양이 다르면 던진다', () async {
      // 배열은 우리 형식이 아니다.
      final e = await _errorOf(() => importStudyData('uid', '[1, 2, 3]'));
      expect(e, isNotNull);
      expect(e.toString(), contains(studyFileUnreadableMessage));
    });

    test('version이 없거나 모르는 값이면 던진다', () async {
      for (final src in <String>[
        '{"sentences": []}',
        '{"version": 0, "sentences": []}',
        '{"version": 999, "sentences": []}',
      ]) {
        final e = await _errorOf(() => importStudyData('uid', src));
        expect(e, isNotNull, reason: src);
        expect(e.toString(), contains(studyFileUnreadableMessage), reason: src);
      }
    });
  });

  test('제대로 읽었는데 더할 것이 없으면 0을 돌려준다', () async {
    // 이건 던지면 안 된다. '이미 다 있다'는 멀쩡한 결과다.
    final count =
        await importStudyData('uid', '{"version": 1, "sentences": [], "words": []}');
    expect(count.sentences, 0);
    expect(count.words, 0);
  });

  test('두 경우의 말이 서로 다르다', () {
    expect(studyFileUnreadableMessage,
        isNot(studyRestoreSummary((sentences: 0, words: 0))));
  });

  test('화면이 그 말을 그대로 보여 준다', () {
    // data_section이 '다시 시도해 주세요'로 덮어쓰면 까닭이 사라진다.
    final code = File(
            'lib/features/settings/more/presentation/sections/data_section.dart')
        .readAsStringSync();
    final body = code.substring(code.indexOf('Future<void> _importStudyFile()'));
    expect(body.substring(0, body.indexOf('\n  }')),
        contains('studyFileUnreadableMessage'));
  });
}
