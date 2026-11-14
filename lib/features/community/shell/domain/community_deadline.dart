/// 커뮤니티에서 마감까지 남은 때를 말하는 한 가지 방법(5차).
///
/// 전에는 같은 것을 화면마다 다르게 불렀다. 투표 카드는 'N일 뒤 마감' ·
/// '투표 마감', 질문 줄은 'N일 남음' · '기한 지남'이었다.
String communityDeadlineLabel(DateTime end, DateTime now) {
  final left = end.difference(now);
  if (left.isNegative) return '마감 지남';
  if (left.inDays > 0) return '${left.inDays}일 뒤 마감';
  if (left.inHours > 0) {
    final minutes = left.inMinutes % 60;
    return minutes == 0
        ? '${left.inHours}시간 뒤 마감'
        : '${left.inHours}시간 $minutes분 뒤 마감';
  }
  if (left.inMinutes > 0) return '${left.inMinutes}분 뒤 마감';
  return '곧 마감';
}
