/// 플레이어에서 보여주는 시각. 예전엔 '00:00.000'처럼 밀리초까지 보여 읽기
/// 어려웠고 재생 중에는 끝자리가 계속 바뀌었다(5차). 영상 앱처럼 '0:03'으로
/// 보인다. 편집 화면(클립 만들기)은 밀리초가 필요해 그대로 둔다.
String clipClock(int ms, {bool tenths = false}) {
  final safe = ms < 0 ? 0 : ms;
  final totalSeconds = safe ~/ 1000;
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = (totalSeconds % 60).toString().padLeft(2, '0');
  final tail = tenths ? '.${(safe % 1000) ~/ 100}' : '';
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$s$tail';
  return '$m:$s$tail';
}

/// 구간 시각 '0:03 – 0:07'. 2초보다 짧은 구간은 초만으로는 시작과 끝이 같아
/// 보일 수 있어 0.1초까지 보인다('0:00.0 – 0:00.5').
String segmentRangeLabel(int startMs, int endMs) {
  final tenths = endMs - startMs < 2000;
  return '${clipClock(startMs, tenths: tenths)} – ${clipClock(endMs, tenths: tenths)}';
}

/// 재생 중에 흐르는 시계. 2초보다 짧은 클립은 0.1초까지 보인다.
///
/// [segmentRangeLabel]과 같은 잣대다. 1.4초짜리 클립을 초로만 적으면 재생
/// 내내 '0:01 / 0:01'이라 숫자가 멈춰 보였다 - 바는 가운데쯤인데 시계는 벌써
/// 끝난 꼴이다. 게다가 구간 칩은 '0:00.0 – 0:01.4'로 적어서, 구간 끝이 전체
/// 길이보다 뒤에 있는 것처럼 한 화면 안에서 말이 엇갈렸다(5차).
///
/// 이 앱의 클립은 쇼츠에서 잘라 온 1~8초가 흔하다. 긴 영상은 예전처럼
/// '0:03'으로 둔다 - 거기서는 끝자리가 계속 바뀌어 읽기만 어렵다.
///
/// [segmentMs]는 구간 재생일 때 지금 도는 구간의 길이다. 전체 재생이면
/// 비운다. 전에는 영상 길이만 봐서, 8초짜리 영상 안의 1.2초 구간을 돌리면
/// 칩은 '0:01.2 – 0:02.4'인데 시계는 '0:01 / 0:08'이었다 - 한 화면에서
/// 두 잣대가 엇갈렸고, 구간을 도는 내내 시계는 두 값만 오갔다(5차).
/// 구간 재생에서는 칩과 같은 잣대(구간 길이)로 본다.
String clipPlayClock(int ms, {required int totalMs, int? segmentMs}) =>
    clipClock(ms, tenths: (segmentMs ?? totalMs) < 2000);
