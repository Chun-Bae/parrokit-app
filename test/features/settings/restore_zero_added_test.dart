// 백업을 불러왔는데 새로 더해진 문장·단어가 없을 때(5차).
//
// 백업 파일에 문장이 들어 있어도, 그 문장이 이미 다 있으면 한 개도
// 더해지지 않는다(MySentenceStore.add가 같은 것을 건너뛴다). 그런데
// 데이터 화면은 0개면 토스트를 아예 띄우지 않아서, 화면에는
// '다 불러왔어요.'만 남았다. 되찾는 자리에서 몇 개 들어왔는지 안 보이면
// 사용자는 다 돌아온 줄 알고 진짜 백업 파일을 지운다.
//
// 시뮬레이터에서 방금 만든 백업을 그대로 다시 불러와 찾았다. 문장·단어
// 파일에서 불러오기 쪽은 처음부터 0개도 알리고 있었다 - 한 흐름이 두
// 가지로 굴면 안 된다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/study_data_transfer.dart';

void main() {
  test('0개여도 그 말을 띄운다', () {
    final code = File(
            'lib/features/settings/more/presentation/sections/data_section.dart')
        .readAsStringSync();
    final body = code.substring(code.indexOf('if (!mounted || !restoring)'));
    final toast = body.indexOf('showToast(studyRestoreSummary(');
    expect(toast, greaterThan(-1), reason: '불러온 결과를 알린다');

    // 개수로 막으면 0개가 묻힌다. 고른 것으로만 가른다.
    final guard = body.substring(0, toast);
    expect(guard.contains('count.sentences > 0'), isFalse,
        reason: '0개라고 입을 다물면 안 된다');
    expect(guard, contains('parts.sentences || parts.words'),
        reason: '클립만 되돌릴 때는 앱이 다시 켜지므로 그때만 건너뛴다');
  });

  test('0개일 때 할 말이 있다', () {
    expect(studyRestoreSummary((sentences: 0, words: 0)), isNotEmpty);
    expect(studyRestoreSummary((sentences: 0, words: 0)),
        isNot(studyRestoreSummary((sentences: 1, words: 0))));
  });
}
