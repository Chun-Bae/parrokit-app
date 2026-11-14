// 쇼츠 위쪽 진행 표시줄 칸 수(5차).
//
// 클립이 두 개뿐인데도 열 칸을 그려서 여덟 개가 더 남은 것처럼 보였다.
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/collection/clip/shorts/presentation/shorts_progress.dart';

void main() {
  test('클립이 묶음보다 적으면 그 수만큼만 그린다', () {
    final bar = shortsProgress(currentIndex: 1, clipCount: 2, pageSize: 10);
    expect(bar.total, 2);
    expect(bar.index, 1);
  });

  test('클립이 묶음보다 많으면 묶음 크기로 그리고 그 안에서 센다', () {
    final bar = shortsProgress(currentIndex: 12, clipCount: 14, pageSize: 10);
    expect(bar.total, 10);
    expect(bar.index, 2);
  });

  test('딱 묶음 크기면 그대로', () {
    final bar = shortsProgress(currentIndex: 9, clipCount: 10, pageSize: 10);
    expect(bar.total, 10);
    expect(bar.index, 9);
  });

  test('클립이 없거나 하나뿐이면 아무 칸도 그리지 않는다', () {
    expect(
        shortsProgress(currentIndex: 0, clipCount: 0, pageSize: 10).total, 0);
    // 하나뿐이면 넘길 곳이 없어 꽉 찬 줄 하나만 보였다.
    expect(
        shortsProgress(currentIndex: 0, clipCount: 1, pageSize: 10).total, 0);
  });
}
