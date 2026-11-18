// 긴 자막이 오른쪽 액션 레일을 덮던 것(5차 492).
//
// 자막은 `left: 16, right: 16`으로 가로를 다 쓰고 레일은 그 위에 떠 있어서,
// 'I keep telling myself I'll do it, but I never actually do.' 같은 긴 줄의
// 끝이 '연습' 단추 글자를 가로질렀다. 짧은 자막에서는 안 보이는 결함이라
// 눈으로만 보고 넘기기 쉽다. 자리를 숫자로 묶어 둔다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/collection/clip/shorts/presentation/widgets/action_rail.dart';

String _code(String path) => File(path)
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('자막이 비우는 자리가 레일보다 넓다', () {
    // 레일은 오른쪽 끝에서 shortsActionRailRight만큼 떨어져 그 폭을 차지한다.
    final railLeftEdge = shortsActionRailRight + shortsActionRailWidth;
    expect(shortsSubtitleRightInset, greaterThan(railLeftEdge),
        reason: '자막이 레일 아래로 들어가면 안 된다');
  });

  test('레일 폭이 글자가 들어갈 만큼은 된다', () {
    // 가장 넓은 글자가 '자동 넘김'이다. 너무 좁히면 줄이 접힌다.
    expect(shortsActionRailWidth, greaterThanOrEqualTo(64));
  });

  test('자막과 레일이 같은 값을 꺼내 쓴다', () {
    final page = _code('lib/features/collection/clip/shorts/presentation/'
        'widgets/shorts_page.dart');
    expect(page, contains('right: shortsSubtitleRightInset'));
    // 가로를 다 쓰던 옛 꼴이 돌아오지 않는다.
    expect(page.contains('left: 16,\n              right: 16,'), isFalse);

    final screen = _code('lib/features/collection/clip/shorts/presentation/'
        'shorts_screen.dart');
    expect(screen, contains('right: shortsActionRailRight'));

    final rail = _code('lib/features/collection/clip/shorts/presentation/'
        'widgets/action_rail.dart');
    expect(rail, contains('width: shortsActionRailWidth'));
  });
}
