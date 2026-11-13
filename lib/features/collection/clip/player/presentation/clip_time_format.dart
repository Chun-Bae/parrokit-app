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
