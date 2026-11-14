// 창이 떠 있는 동안 무대를 멈춘다(5차).
//
// 문장 목록을 열어 둔 채 앵무새가 다음 문장으로 넘어가서, 목록에 파랗게
// 표시된 '지금 문장'이 실제와 달랐다. 가린 화면 뒤에서 소리도 계속 났다.
// 위젯 테스트로는 이 흐름을 재현하지 못해(가짜 TTS는 넘어가지 않는다),
// 창을 여는 네 곳이 멈춤 도우미를 거치는지 코드로 지킨다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('창을 여는 곳은 모두 whilePaused를 거친다', () {
    final code = File(
      'lib/features/home/dashboard/presentation/stage_preview_screen.dart',
    ).readAsStringSync();

    // 선언 하나 + 문장 목록·말하기 설정·문장 설정·문장 추가 네 곳.
    expect('whilePaused'.allMatches(code).length, greaterThanOrEqualTo(5));
    expect(code, contains('showAppSheet<int>'));
    expect(
      code.contains('final picked = await whilePaused('),
      isTrue,
      reason: '문장 목록',
    );
    expect(
      code.contains('final action = await whilePaused('),
      isTrue,
      reason: '문장 설정',
    );
    expect(
      code.contains('result = await whilePaused('),
      isTrue,
      reason: '문장 추가',
    );
    // 멈춤 조건에 창 상태가 들어 있다.
    expect(code, contains('|| paused || sheetOpen'));
  });
}
