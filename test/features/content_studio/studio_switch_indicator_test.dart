// 콘텐츠 제작 전환 줄의 선택 표시가 칸 수에 맞게 서는지 본다.
//
// 영상 탭을 끄면 칸이 둘인데 표시만 세 칸 기준이라 가운데 빈 곳에 떠
// 있었다(5차).

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/home/dashboard/presentation/widgets/dashboard_studio_switch_fab.dart';

void main() {
  test('두 칸이면 왼쪽 끝과 오른쪽 끝에 선다', () {
    expect(studioSwitchIndicatorX(count: 2, index: 0), -1);
    expect(studioSwitchIndicatorX(count: 2, index: 1), 1);
  });

  test('세 칸이면 왼쪽·가운데·오른쪽', () {
    expect(studioSwitchIndicatorX(count: 3, index: 0), -1);
    expect(studioSwitchIndicatorX(count: 3, index: 1), 0);
    expect(studioSwitchIndicatorX(count: 3, index: 2), 1);
  });

  test('칸 밖 번호는 끝으로 붙인다', () {
    expect(studioSwitchIndicatorX(count: 2, index: 5), 1);
    expect(studioSwitchIndicatorX(count: 2, index: -3), -1);
  });

  test('칸이 하나뿐이면 가운데', () {
    expect(studioSwitchIndicatorX(count: 1, index: 0), 0);
    expect(studioSwitchIndicatorX(count: 0, index: 0), 0);
  });
}
