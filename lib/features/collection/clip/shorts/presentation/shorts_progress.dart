// 쇼츠 위쪽 진행 표시줄이 몇 칸을 그리고 어디를 밝힐지 계산한다.
//
// 전에는 칸 수를 늘 한 묶음 크기(10)로 그렸다. 클립이 두 개뿐인 사람에게도
// 열 칸이 보여서, 여덟 개가 더 남은 것처럼 읽혔다(5차).
class ShortsProgress {
  const ShortsProgress({required this.index, required this.total});

  /// 밝힐 칸의 자리(0부터).
  final int index;

  /// 그릴 칸 수.
  final int total;
}

/// [clipCount]개를 들고 있고 [currentIndex]번째를 보고 있을 때의 표시줄.
///
/// 클립이 한 묶음보다 적으면 그만큼만 그린다. 묶음보다 많으면(다음 묶음을
/// 미리 받아 둔 때) 한 묶음 크기로 그리고 그 안에서 자리를 센다.
ShortsProgress shortsProgress({
  required int currentIndex,
  required int clipCount,
  required int pageSize,
}) {
  // 클립이 하나뿐이면 넘길 곳이 없어 칸이 아무것도 알려 주지 않는다.
  // 꽉 찬 줄 하나만 그려져 오히려 재생 진행처럼 읽혀서 그리지 않는다.
  if (clipCount <= 1 || pageSize <= 0) {
    return const ShortsProgress(index: 0, total: 0);
  }
  final total = clipCount < pageSize ? clipCount : pageSize;
  final safeIndex = currentIndex < 0 ? 0 : currentIndex;
  return ShortsProgress(index: safeIndex % total, total: total);
}
