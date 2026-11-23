// 자막 초안을 받은 뒤 알릴 말(5차 567).
//
// 서버가 소리를 알아들어도 **해석과 발음은 비어 올 수 있다**. 말이 아닌
// 소리(비프음·웃음)거나 모델이 옮길 것이 없다고 본 때다. 그런데 저장은
// 구간마다 원문·해석·발음을 모두 요구한다. 기기에서 보니 패롯을 쓰고
// '자막 생성 완료!'를 본 뒤에야, 저장을 누를 수 없고 까닭도 버튼 아래
// 작은 글씨로만 나왔다.
//
// 그래서 완료를 알릴 때 빈 칸이 있으면 그 자리에서 함께 말한다.

import 'models/clip_form_data.dart';

/// 해석이나 발음이 빈 구간이 하나라도 있는지.
bool draftHasBlankFields(List<SegmentInput> segments) => segments.any(
      (s) =>
          s.original.trim().isNotEmpty &&
          (s.ko.trim().isEmpty || s.pron.trim().isEmpty),
    );

/// 자막 초안을 받은 뒤 띄울 말.
///
/// [charged]가 0이면 패롯을 쓰지 않은 것이라 값은 적지 않는다.
String captionDraftToast({
  required int charged,
  required bool hasBlank,
}) {
  final head = charged > 0 ? '자막 생성 완료! ($charged패롯 소모)' : '자막 생성 완료!';
  if (!hasBlank) return head;
  return '$head 해석·발음이 빈 구간이 있어요. 채워야 저장할 수 있어요.';
}
