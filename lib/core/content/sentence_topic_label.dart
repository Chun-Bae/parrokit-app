// 공유 문장 카드에 붙는 주제 이름(5차 337, 사용자 신고).
//
// 문장을 직접 적어 저장하면 주제가 '내 문장'으로 들어간다(기본값). 그 문장을
// 둘러보기에 공개하면 다른 사람 화면에도 '내 문장'이라고 떠서, 남이 올린 글이
// 자기 것처럼 보였다("Where were we?가 내 문장이라고 뜬다").
//
// 주제 값 자체는 바꾸지 않는다(이미 올라간 문장들이 그 값을 들고 있다).
// 보여 줄 때만 보는 사람에 따라 말을 고른다.

/// 직접 적은 문장에 기본으로 붙는 주제. 저장할 때 쓰는 값이다.
const String myOwnSentenceTopic = '내 문장';

/// 남이 직접 적어 올린 문장에 보여 줄 말.
const String writtenSentenceTopic = '직접 쓴 문장';

/// [topic]을 화면에 보여 줄 말로 바꾼다.
///
/// [mine]은 보는 사람이 그 문장을 올린 사람인지. 내 것이면 '내 문장' 그대로
/// 두고, 남의 것이면 '직접 쓴 문장'으로 바꾼다. 일상·여행처럼 고른 주제는
/// 누가 보든 그대로다.
String sentenceTopicLabel(String topic, {required bool mine}) {
  final value = topic.trim();
  if (value.isEmpty || value == myOwnSentenceTopic) {
    return mine ? myOwnSentenceTopic : writtenSentenceTopic;
  }
  return value;
}
