// '한 줄씩 멈춤'은 전체 재생에서만 뜻이 있다. 예전에는 구간일 때 흐리게 두고
// 누를 수도 없어서, 왜 안 되는지 알 길이 없었다(5차).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/collection/clip/player/domain/player_state.dart';
import 'package:parrokit/features/collection/clip/player/presentation/pause_each_line_hint.dart';

void main() {
  test('전체 재생이면 막지 않는다', () {
    expect(pauseEachLineDisabledReason(PlayScope.full), isNull);
  });

  test('구간 재생이면 까닭을 알려 준다', () {
    final reason = pauseEachLineDisabledReason(PlayScope.segment);
    expect(reason, isNotNull);
    // 화면에 있는 말('전체'·'구간')로 적는다. 내부 이름(full/segment)은 쓰지 않는다.
    expect(reason, contains('전체'));
    expect(reason, contains('구간'));
    expect(reason!.toLowerCase().contains('scope'), isFalse);
  });

  test('구간일 때는 눌러도 켜지지 않고 까닭만 알린다', () {
    final code = File(
            'lib/features/collection/clip/player/presentation/clip_player_screen.dart')
        .readAsStringSync();
    // 누를 수 없게 막아 두면 까닭을 말할 기회가 없다. 백그라운드만 막는다.
    expect(code, contains('ignoring: vm.isBackground,'));
    expect(
      code,
      contains('pauseEachLineDisabledReason(vm.scope)'),
    );
    expect(code, contains('showToast(blockedReason)'));
    // 막힌 동안에는 켜진 것처럼 칠하지 않는다.
    expect(code, contains('blockedReason == null && vm.pauseEachLine'));
  });
}
