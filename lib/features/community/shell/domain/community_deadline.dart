/// 커뮤니티에서 마감까지 남은 때를 말하는 한 가지 방법(5차).
///
/// 전에는 같은 것을 화면마다 다르게 불렀다. 투표 카드는 'N일 뒤 마감' ·
/// '투표 마감', 질문 줄은 'N일 남음' · '기한 지남'이었다.
String communityDeadlineLabel(DateTime end, DateTime now) {
  final left = end.difference(now);
  if (left.isNegative) return '마감 지남';
  // 하루 넘게 남았으면 달력 날짜로 센다(5차). 시각 차이(inDays)로 세면 '3일 뒤'를
  // 고르고 올린 투표가 그 자리에서 '2일 뒤 마감'이 됐다 - 72시간에서 올리는 데
  // 걸린 몇 초가 모자라 2일로 깎였다. 단어 복습도 같은 까닭으로 달력 날짜를 쓴다.
  if (left.inHours >= 24) {
    final days = DateTime(end.year, end.month, end.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    return '$days일 뒤 마감';
  }
  if (left.inHours > 0) {
    final minutes = left.inMinutes % 60;
    return minutes == 0
        ? '${left.inHours}시간 뒤 마감'
        : '${left.inHours}시간 $minutes분 뒤 마감';
  }
  if (left.inMinutes > 0) return '${left.inMinutes}분 뒤 마감';
  return '곧 마감';
}
