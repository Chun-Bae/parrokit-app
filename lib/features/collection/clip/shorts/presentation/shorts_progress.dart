// 쇼츠 위쪽 진행 표시줄이 몇 칸을 그리고 어디를 밝힐지 계산한다.
//
// 전에는 칸 수를 늘 한 묶음 크기(10)로 그렸다. 클립이 두 개뿐인 사람에게도
// 열 칸이 보여서, 여덟 개가 더 남은 것처럼 읽혔다(5차).
//
// 그 뒤로는 피드에 실린 수를 셌는데, 쇼츠는 끝까지 넘기면 같은 클립을 또
// 무작위로 실어 붙인다(`ShortsProvider._loadRandomClips`). 그래서 클립이
// 다섯 개뿐이어도 한 바퀴 돌 때마다 칸이 5 → 10 → 15로 늘어, 고쳤던 결함이
// 그대로 되살아났다(5차 491). 이제는 **서로 다른 클립 수**를 센다.
class ShortsProgress {
  const ShortsProgress({required this.index, required this.total});

  /// 밝힐 칸의 자리(0부터).
  final int index;

  /// 그릴 칸 수.
  final int total;
}

/// 피드에 실린 클립 id를 실린 차례대로 받아 표시줄을 계산한다.
///
/// [clipIds]에는 같은 id가 여러 번 들어올 수 있다(되풀이해 실은 것).
/// 칸은 서로 다른 클립마다 하나씩이고, 밝히는 자리는 지금 보는 클립이
/// 그 가운데 몇 번째인지다. 그래서 한 바퀴를 더 돌아도 같은 클립이면
/// 같은 칸이 밝는다.
ShortsProgress shortsProgress({
  required int currentIndex,
  required List<int> clipIds,
  required int pageSize,
}) {
  if (pageSize <= 0 || clipIds.isEmpty) {
    return const ShortsProgress(index: 0, total: 0);
  }

  // 처음 실린 차례를 지킨 '서로 다른 클립' 목록.
  final distinct = <int>[];
  for (final id in clipIds) {
    if (!distinct.contains(id)) distinct.add(id);
  }

  // 클립이 하나뿐이면 넘길 곳이 없어 칸이 아무것도 알려 주지 않는다.
  // 꽉 찬 줄 하나만 그려져 오히려 재생 진행처럼 읽혀서 그리지 않는다.
  if (distinct.length <= 1) return const ShortsProgress(index: 0, total: 0);

  final total = distinct.length < pageSize ? distinct.length : pageSize;
  final safeIndex = currentIndex < 0
      ? 0
      : (currentIndex >= clipIds.length ? clipIds.length - 1 : currentIndex);
  final place = distinct.indexOf(clipIds[safeIndex]);
  return ShortsProgress(index: place % total, total: total);
}
