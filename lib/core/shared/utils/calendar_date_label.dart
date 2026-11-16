/// 오래된 시각을 날짜로 적는다. **올해가 아니면 연도까지** 붙인다.
///
/// 커뮤니티 글, 문장 친밀도, 홈의 둘러보기 카드가 저마다 같은 규칙을 적어
/// 두고 있었는데, 홈 카드만 연도를 빼먹어 작년 글이 올해 글처럼 보였다(5차).
/// 규칙은 여기 한 곳에만 둔다.
String calendarDateLabel(DateTime at, DateTime now) {
  final local = at.toLocal();
  return local.year == now.year
      ? '${local.month}월 ${local.day}일'
      : '${local.year}년 ${local.month}월 ${local.day}일';
}
