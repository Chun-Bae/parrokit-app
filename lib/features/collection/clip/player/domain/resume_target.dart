// 앱을 내렸다 돌아왔을 때 영상을 어디에 맞출지(5차, 사용자 신고).
//
// 소리로 이어 듣던 자리를 그대로 영상에 넘기면, 끝까지 듣고 반복으로 넘어간
// 순간에는 '맨 끝'이 넘어온다. 그 자리에 맞추고 재생을 누르면 이미 끝이라
// 아무 일도 안 일어나, 돌아왔을 때 영상이 끝에 붙은 채 멈춰 있었다.

/// 돌아왔을 때 영상을 맞출 자리.
///
/// [segmentScope]면 구간 밖이면 구간 처음으로. 전체 재생이면 끝에 닿았을 때
/// 처음으로 돌린다. [duration]을 모르면(0) 받은 자리를 그대로 쓴다.
Duration resumeTargetAfterBackground({
  required Duration position,
  required bool segmentScope,
  required Duration segmentStart,
  required Duration segmentEnd,
  required Duration duration,
}) {
  if (position < Duration.zero) {
    return segmentScope ? segmentStart : Duration.zero;
  }
  if (segmentScope) {
    if (position < segmentStart || position >= segmentEnd) return segmentStart;
    return position;
  }
  // 끝에서 몇 밀리초 못 미친 자리도 '끝'으로 본다. 소리 쪽이 알려 주는 자리가
  // 딱 떨어지지 않는다.
  const edge = Duration(milliseconds: 200);
  if (duration > Duration.zero && position >= duration - edge) {
    return Duration.zero;
  }
  return position;
}
