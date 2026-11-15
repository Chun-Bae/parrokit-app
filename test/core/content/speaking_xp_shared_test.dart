// 홈 무대와 문장 상세가 같은 자리에 XP를 쌓는지.

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/speaking_xp.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('XP 자리는 계정마다 하나다', () {
    expect(speakingXpKey('uid-1'), 'parrokit.speaking.xp.v1.uid-1');
    expect(speakingXpKey('guest'), isNot(speakingXpKey('uid-1')));
  });

  test('연습할 때마다 같은 자리에 쌓인다', () async {
    SharedPreferences.setMockInitialValues({});

    final first = await addSpeakingXp('uid-1', 1.0);
    expect(first, 1);
    final second = await addSpeakingXp('uid-1', 0.5);
    expect(second, 1.5);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble(speakingXpKey('uid-1')), 1.5);
  });

  test('점수가 없어도 최소만큼은 쌓인다', () async {
    SharedPreferences.setMockInitialValues({});
    final total = await addSpeakingXp('uid-2', null);
    expect(total, minXpGain);
  });

  test('다른 계정의 XP는 섞이지 않는다', () async {
    SharedPreferences.setMockInitialValues({});
    await addSpeakingXp('uid-1', 1.0);
    final other = await addSpeakingXp('uid-2', 1.0);
    expect(other, 1);
  });
}
