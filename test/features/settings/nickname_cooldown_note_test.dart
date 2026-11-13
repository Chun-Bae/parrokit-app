// 닉네임 30일 규칙 안내(5차): 오류처럼 빨갛게 한 줄로 보이던 것을 언제 바꿀 수 있는지로.
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/settings/more/presentation/profile_edit_screen.dart';

void main() {
  test('남은 날을 언제 바꿀 수 있는지로 말한다', () {
    expect(nicknameCooldownNote(12), contains('12일 뒤에 바꿀 수 있어요'));
    expect(nicknameCooldownNote(1), contains('내일부터'));
    expect(nicknameCooldownNote(30), startsWith('닉네임은 30일에 한 번'));
  });
}
