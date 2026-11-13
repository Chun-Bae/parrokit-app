import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/collection/clip/player/presentation/line_pause_gate.dart';

Duration ms(int v) => Duration(milliseconds: v);

void main() {
  test('줄이 끝나기 전에는 멈추지 않고, 끝나면 한 번만 멈춘다', () {
    final gate = LinePauseGate();
    expect(gate.shouldPause(0, ms(500), ms(1000)), isFalse);
    expect(gate.shouldPause(0, ms(1000), ms(1000)), isTrue);
    // 다시 재생해 같은 줄 끝을 지나는 동안은 또 멈추지 않는다.
    expect(gate.shouldPause(0, ms(1100), ms(1000)), isFalse);
    expect(gate.shouldPause(0, ms(1300), ms(1000)), isFalse);
  });

  test('다음 줄은 그 줄 끝에서 다시 멈춘다', () {
    final gate = LinePauseGate();
    expect(gate.shouldPause(0, ms(1000), ms(1000)), isTrue);
    expect(gate.shouldPause(1, ms(1500), ms(2000)), isFalse);
    expect(gate.shouldPause(1, ms(2000), ms(2000)), isTrue);
  });

  test('같은 줄 앞으로 돌아가 다시 들으면 그 줄 끝에서 또 멈춘다', () {
    final gate = LinePauseGate();
    expect(gate.shouldPause(0, ms(1000), ms(1000)), isTrue);
    expect(gate.shouldPause(0, ms(200), ms(1000)), isFalse); // 되감기
    expect(gate.shouldPause(0, ms(1000), ms(1000)), isTrue);
  });

  test('reset 뒤에는 같은 줄 끝에서 다시 멈출 수 있다', () {
    final gate = LinePauseGate();
    expect(gate.shouldPause(0, ms(1000), ms(1000)), isTrue);
    gate.reset();
    expect(gate.shouldPause(0, ms(1100), ms(1000)), isTrue);
  });
}
