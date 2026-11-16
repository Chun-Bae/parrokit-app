// 공유 문장이 올라온 지 얼마나 됐는지(5차 339).
//
// 홈 '공유 문장' 카드가 쓰던 규칙을 둘러보기 카드도 같이 쓰려고 꺼냈다.
// 일주일이 넘으면 날짜로 적되, 연도 규칙은 커뮤니티와 같은 곳에서 가져온다
// (예전에는 여기만 연도를 안 붙여 작년 글이 올해 글로 보였다, 5차).

import 'package:parrokit/core/shared/utils/calendar_date_label.dart';

String sentenceAgeLabel(DateTime? at, DateTime now) {
  if (at == null) return '방금';
  final diff = now.difference(at);
  if (diff.inMinutes < 1) return '방금';
  if (diff.inHours < 1) return '${diff.inMinutes}분 전';
  if (diff.inDays < 1) return '${diff.inHours}시간 전';
  if (diff.inDays < 7) return '${diff.inDays}일 전';
  return calendarDateLabel(at, now);
}
