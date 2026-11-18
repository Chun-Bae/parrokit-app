// 쇼츠 위쪽 진행 표시줄 칸 수(5차, 491에서 갱신).
//
// 클립이 두 개뿐인데도 열 칸을 그려서 여덟 개가 더 남은 것처럼 보였다.
// 피드에 실린 수를 세게 고쳤더니, 끝까지 넘겨 같은 클립을 또 실을 때마다
// 칸이 5 → 10 → 15로 늘어 같은 결함이 돌아왔다. 이제는 서로 다른 클립을 센다.
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/collection/clip/shorts/presentation/shorts_progress.dart';

/// [count]개를 차례대로 실은 피드.
List<int> _feed(int count) => [for (var i = 0; i < count; i++) i];

void main() {
  test('클립이 묶음보다 적으면 그 수만큼만 그린다', () {
    final bar =
        shortsProgress(currentIndex: 1, clipIds: _feed(2), pageSize: 10);
    expect(bar.total, 2);
    expect(bar.index, 1);
  });

  test('클립이 묶음보다 많으면 묶음 크기로 그리고 그 안에서 센다', () {
    final bar =
        shortsProgress(currentIndex: 12, clipIds: _feed(14), pageSize: 10);
    expect(bar.total, 10);
    expect(bar.index, 2);
  });

  test('딱 묶음 크기면 그대로', () {
    final bar =
        shortsProgress(currentIndex: 9, clipIds: _feed(10), pageSize: 10);
    expect(bar.total, 10);
    expect(bar.index, 9);
  });

  test('클립이 없거나 하나뿐이면 아무 칸도 그리지 않는다', () {
    expect(shortsProgress(currentIndex: 0, clipIds: const [], pageSize: 10).total, 0);
    // 하나뿐이면 넘길 곳이 없어 꽉 찬 줄 하나만 보였다.
    expect(shortsProgress(currentIndex: 0, clipIds: const [7], pageSize: 10).total, 0);
    // 같은 하나를 되풀이해 실어도 마찬가지다.
    expect(
        shortsProgress(currentIndex: 3, clipIds: const [7, 7, 7, 7], pageSize: 10)
            .total,
        0);
  });

  group('같은 클립을 또 실어도 칸이 늘지 않는다(5차 491)', () {
    // 클립 다섯 개를 두 바퀴 실은 피드. 끝까지 넘기면 쇼츠가 이렇게 쌓는다.
    final twice = const [1, 2, 3, 4, 5, 3, 1, 5, 2, 4];

    test('칸은 다섯 개 그대로다', () {
      for (var i = 0; i < twice.length; i++) {
        expect(shortsProgress(currentIndex: i, clipIds: twice, pageSize: 10).total,
            5,
            reason: '$i번째');
      }
    });

    test('같은 클립이면 두 바퀴째도 같은 칸이 밝는다', () {
      // 자리 0과 6은 둘 다 클립 1이다.
      expect(shortsProgress(currentIndex: 0, clipIds: twice, pageSize: 10).index,
          shortsProgress(currentIndex: 6, clipIds: twice, pageSize: 10).index);
      // 자리 2와 5는 둘 다 클립 3이다.
      expect(shortsProgress(currentIndex: 2, clipIds: twice, pageSize: 10).index,
          shortsProgress(currentIndex: 5, clipIds: twice, pageSize: 10).index);
    });

    test('밝히는 자리는 그 클립이 처음 실린 차례다', () {
      expect(shortsProgress(currentIndex: 5, clipIds: twice, pageSize: 10).index, 2);
      expect(shortsProgress(currentIndex: 9, clipIds: twice, pageSize: 10).index, 3);
    });
  });

  test('자리가 범위를 벗어나도 넘어지지 않는다', () {
    final bar =
        shortsProgress(currentIndex: 99, clipIds: _feed(3), pageSize: 10);
    expect(bar.total, 3);
    expect(bar.index, 2);
    expect(shortsProgress(currentIndex: -1, clipIds: _feed(3), pageSize: 10).index,
        0);
  });
}
