// 공유 문장이 올라온 지 얼마나 됐는지(5차 339).
//
// 세는 규칙은 커뮤니티와 한 곳에서 가져온다(5차 443). 전에는 같은 계산이
// 두 벌이었고, 막 올라온 것을 여기서는 '방금', 커뮤니티에서는 '방금 전'
// 이라고 불렀다.

import 'package:parrokit/core/shared/utils/time_ago_label.dart';

String sentenceAgeLabel(DateTime? at, DateTime now) {
  if (at == null) return justNowLabel;
  return timeAgoLabel(at, now);
}
