// 지난 시간을 사람 말로 적는다(5차 443).
//
// 같은 계산이 두 벌이었다. 문장 카드(sentence_age_label)와 커뮤니티
// (formatCommunityTimeAgo)가 각자 분·시간·일을 세고, 일주일이 넘으면
// 날짜로 바꿨다. 그런데 **막 올라온 것을 한쪽은 '방금', 다른 쪽은
// '방금 전'**이라고 불렀다. 같은 상황인데 화면마다 다르게 보인다.
//
// '1분 전', '2시간 전'과 짝이 맞는 '방금 전'으로 모은다.

import 'package:parrokit/core/shared/utils/calendar_date_label.dart';

/// 올라온 지 1분이 안 됐을 때.
const String justNowLabel = '방금 전';

/// 'N분 전' · 'N시간 전' · 'N일 전', 일주일이 넘으면 날짜.
///
/// 날짜는 [calendarDateLabel]이 정한다(올해가 아니면 연도를 붙인다).
String timeAgoLabel(DateTime at, DateTime now) {
  final diff = now.difference(at);
  if (diff.inDays >= 7) return calendarDateLabel(at, now);
  if (diff.inDays > 0) return '${diff.inDays}일 전';
  if (diff.inHours > 0) return '${diff.inHours}시간 전';
  if (diff.inMinutes > 0) return '${diff.inMinutes}분 전';
  return justNowLabel;
}
