// 연습하는 자리 셋이 모두 같은 지급 길을 쓴다(5차 505).
//
// 자리마다 따로 크래커를 더하면 상한이 갈라진다. 한 자리만 빠뜨려도
// '연습하면 받는다'는 말이 어느 화면에서는 거짓이 된다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/practice_reward.dart';

void main() {
  const sites = {
    '보관함 문장 창(따라 말하기)':
        'lib/features/collection/shell/presentation/widgets/sentence_collection_preview.dart',
    '홈 무대(따라 말하기)':
        'lib/features/home/dashboard/presentation/character_dashboard_screen.dart',
    '단어 복습':
        'lib/features/collection/shell/presentation/widgets/word_collection_preview.dart',
  };

  String read(String path) => File(path)
      .readAsStringSync()
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('//'))
      .join('\n');

  test('연습하는 자리 셋이 grantPracticeReward를 부른다', () {
    sites.forEach((name, path) {
      expect(read(path), contains('grantPracticeReward('), reason: name);
    });
  });

  test('화면이 크래커를 직접 더하지 않는다', () {
    // 상한을 거치지 않고 더하면 장부와 잔액이 어긋난다.
    sites.forEach((name, path) {
      expect(read(path).contains('addCrackers('), isFalse, reason: name);
    });
  });

  test('받은 수는 공용 글귀로 적는다', () {
    sites.forEach((name, path) {
      expect(read(path), contains('practiceRewardEarned('), reason: name);
    });
  });

  test('지급은 장부에 적기 전에 잔액을 먼저 바꾼다', () {
    // 잔액에 더하지 못했는데 장부에만 적히면 받지도 않고 상한이 깎인다.
    final src = read('lib/core/state/practice_reward_grant.dart');
    expect(src.indexOf('addCrackers('),
        lessThan(src.indexOf('PracticeRewardStore.confirm(')));
    expect(src, contains('PracticeRewardStore.prepare('));
  });

  test('상한 글귀는 한 곳에서만 만든다', () {
    // 화면이 각자 '하루 300개'라고 적으면 숫자를 고칠 때 갈라진다.
    for (final path in sites.values) {
      final src = read(path);
      expect(src.contains('$rewardDailyCap개'), isFalse, reason: path);
      expect(src.contains('$rewardWeeklyCap'), isFalse, reason: path);
    }
    expect(practiceRewardCapSummary, contains('$rewardDailyCap'));
  });
}
