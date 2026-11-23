// 따라 말하기 점수가 숙련도에 어떻게 반영되는지(5차, 사용자 요청).

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/sentence_activity_store.dart';
import 'package:parrokit/core/content/sentence_mastery.dart';

void main() {
  // 1/2/3으로 바꿨다(5차 566). 0점은 주지 않는다 - "했는데 아무것도 안
  // 쌓였다"가 되는데, 같은 순간 홈 헤더는 XP가 올랐다고 적어 말이 갈렸다.
  test('잘 따라 할수록 많이 오른다', () {
    expect(practiceGain(1.0), 3, reason: '100점');
    expect(practiceGain(0.9), 3, reason: '85점 위는 세 점');
    expect(practiceGain(0.7), 2, reason: '60~85점');
    expect(practiceGain(0.2), 1, reason: '잘 못해도 한 점은 쌓인다');
    expect(practiceGain(null), 1, reason: '점수를 모르면 하한');
  });

  test('점수 범위를 벗어나도 1~3점 안에 든다', () {
    expect(practiceGain(5), 3);
    expect(practiceGain(-1), 1);
  });

  test('쌓인 점수로 친밀도가 오른다', () {
    const low = SentenceActivity(practiceCount: 3, practicePoints: 0);
    const high = SentenceActivity(practiceCount: 3, practicePoints: 6);

    expect(affinityOf(low).points, 0);
    expect(affinityOf(high).points, 6);
    expect(affinityOf(high).level, greaterThan(affinityOf(low).level));
    expect(masteryOf(high).index, greaterThanOrEqualTo(masteryOf(low).index));
  });

  test('예전 기록은 횟수당 2점으로 읽어 그대로 보인다', () {
    const old = SentenceActivity(practiceCount: 4);

    expect(old.practicePoints, isNull);
    expect(old.practiceScore, 8);
    expect(affinityOf(old).points, 8);
  });

  test('저장했다 읽어도 점수가 남는다', () {
    const activity = SentenceActivity(practiceCount: 2, practicePoints: 3);
    final json = activity.toJson();
    final restored = SentenceActivity.fromJson(Map<String, dynamic>.from(json));

    expect(restored.practicePoints, 3);
    expect(restored.practiceScore, 3);
  });
}
