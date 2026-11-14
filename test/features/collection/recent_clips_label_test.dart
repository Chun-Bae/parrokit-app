// 최근 본 클립 줄의 이름(5차). 하는 일대로 부른다.
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/recent_clips_label.dart';

void main() {
  test("'이어보기'라고 부르지 않는다", () {
    // 재생 위치를 기억하지 않아 누르면 처음부터 다시 튼다. 기록도
    // recent_clip_views(최근 본 클립)다.
    for (final text in [
      recentClipsTitle,
      recentClipsSubtitle,
      recentClipPlayLabel,
    ]) {
      expect(text.contains('이어보기'), isFalse, reason: text);
      expect(text.trim(), isNotEmpty);
    }
  });

  test('제목과 버튼이 본 것을 다시 본다는 말을 쓴다', () {
    expect(recentClipsTitle, '최근 본 클립');
    expect(recentClipPlayLabel, '다시 보기');
  });
}
