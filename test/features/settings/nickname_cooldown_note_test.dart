// 닉네임 30일 규칙 안내(5차): 오류처럼 빨갛게 한 줄로 보이던 것을 언제 바꿀 수 있는지로.
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/settings/more/presentation/profile_edit_screen.dart';

void main() {
  _saveBlockedTests();

  test('남은 날을 언제 바꿀 수 있는지로 말한다', () {
    expect(nicknameCooldownNote(12), contains('12일 뒤에 바꿀 수 있어요'));
    expect(nicknameCooldownNote(1), contains('내일부터'));
    expect(nicknameCooldownNote(30), startsWith('닉네임은 30일에 한 번'));
  });

  test('30일이 지나면 지금 바꿀 수 있다고 알려준다', () {
    final now = DateTime(2026, 11, 14);
    // 같은 해면 연도를 붙이지 않는다(앱의 다른 날짜 표시와 같게).
    expect(nicknameReadyNote(now, DateTime(2026, 5, 27)),
        '지금 바꿀 수 있어요. 마지막으로 바꾼 날은 5월 27일이고, '
        '바꾸면 30일 동안 다시 바꿀 수 없어요.');
    // 해가 다르면 연도를 붙인다.
    expect(nicknameReadyNote(now, DateTime(2025, 12, 31)),
        contains('2025년 12월 31일'));
    // 가까운 날은 '어제'처럼 읽는다.
    expect(nicknameReadyNote(now, DateTime(2026, 11, 13)), contains('어제'));
  });
}

void _saveBlockedTests() {
  group("꺼진 '완료'를 누르면 까닭을 말한다", () {
    String reason({
      bool hasChanges = true,
      bool hasNicknameChanged = true,
      bool nicknameChecked = true,
      bool canChangeNickname = true,
    }) =>
        profileSaveBlockedReason(
          hasChanges: hasChanges,
          hasNicknameChanged: hasNicknameChanged,
          nicknameChecked: nicknameChecked,
          canChangeNickname: canChangeNickname,
        );

    test('바꾼 것이 없으면 그렇게 말한다', () {
      expect(reason(hasChanges: false), '바뀐 것이 없어요.');
    });

    test('중복 확인을 안 했으면 버튼 이름 그대로 알려 준다', () {
      expect(reason(nicknameChecked: false), contains('중복 확인'));
    });

    test('30일이 안 지났으면 그 규칙을 먼저 말한다', () {
      // 확인도 안 했고 기한도 안 됐으면, 눌러도 소용없는 기한부터 알린다.
      expect(reason(nicknameChecked: false, canChangeNickname: false),
          contains('30일에 한 번'));
    });
  });
}
