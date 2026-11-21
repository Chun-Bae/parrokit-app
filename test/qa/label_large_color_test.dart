// labelLarge를 글에 쓸 때는 색을 적어야 한다(5차 533).
//
// app_texts_theme.dart가 labelLarge에 color: cs.onPrimary를 박아 둔다.
// 버튼 글자용이라 그렇다. 밝은 바탕의 본문이나 제목에 그대로 쓰면 흰 글자가
// 되어 **아무것도 안 보인다.**
//
// 기기에서 두 번 걸렸다. 학습 캘린더의 미터 줄에서 한 번(주석으로만 남겼다),
// 더보기의 '오늘 쓴 자동 채우기' 제목에서 또 한 번. 주석은 다음 사람을 못
// 막으니 테스트로 막는다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// style 한 덩이 안에서 labelLarge를 쓰면서 color를 안 적은 자리.
///
/// `context.texts.labelLarge` 뒤 `.copyWith(...)` 괄호 안에 color가 있는지
/// 본다. ElevatedButton 등의 `textStyle:`은 버튼이 제 색을 입히므로 뺀다.
List<String> _offenders(File file) {
  final text = file.readAsStringSync();
  final out = <String>[];
  for (final m in RegExp(r'[\w.]*texts\.labelLarge([\s\S]{0,160})')
      .allMatches(text)) {
    final tail = m.group(1)!;
    // 이 쓰임이 끝나는 곳까지만 본다(다음 줄의 다른 위젯까지 보지 않게).
    final chunk = tail.split(RegExp(r'\),\s*\n\s*[A-Z]')).first;
    if (chunk.contains('color:')) continue;
    // 버튼 스타일은 버튼이 색을 정한다. 줄바꿈돼 있을 수 있으므로
    // 바로 앞 토막에서 찾는다.
    final before = text.substring(0, m.start);
    final near = before.length > 60
        ? before.substring(before.length - 60)
        : before;
    if (near.contains('textStyle:')) continue;
    final lineNo = '\n'.allMatches(before).length + 1;
    out.add('${file.path}:$lineNo');
  }
  return out;
}

Iterable<File> _dartFiles(String root) => Directory(root)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

void main() {
  test('labelLarge를 글에 쓰면 색을 함께 적는다', () {
    final offenders = [
      for (final f in _dartFiles('lib')) ..._offenders(f),
    ];
    expect(
      offenders,
      isEmpty,
      reason: 'labelLarge는 색이 onPrimary(흰색)다. 밝은 바탕에서 글자가 사라진다.\n'
          '색을 적거나 bodyMedium 같은 본문 스타일을 쓰세요:\n'
          '${offenders.join('\n')}',
    );
  });
}
