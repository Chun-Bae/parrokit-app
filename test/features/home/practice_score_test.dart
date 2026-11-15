// 따라 말하기 점수가 숙련도에 어떻게 반영되는지(5차, 사용자 요청).

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/sentence_activity_store.dart';
import 'package:parrokit/core/content/sentence_mastery.dart';

void main() {
  test('잘 따라 할수록 많이 오른다', () {
    expect(practiceGain(1.0), 2, reason: '100점');
    expect(practiceGain(0.5), 1, reason: '50점');
    expect(practiceGain(0.2), 0, reason: '거의 못 따라 했으면 안 오른다');
    expect(practiceGain(null), 1, reason: '점수를 모르면 중간값');
  });

  test('점수 범위를 벗어나도 0~2점 안에 든다', () {
    expect(practiceGain(5), 2);
    expect(practiceGain(-1), 0);
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
