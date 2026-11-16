// 공유 문장 카드에 붙는 주제 이름(5차 337·338, 사용자 신고).
//
// 문장을 직접 적어 저장하면 주제가 '내 문장'으로 들어간다(기본값). 그 문장을
// 둘러보기에 공개하면 다른 사람 화면에도 '내 문장'이라고 떠서, 남이 올린 글이
// 자기 것처럼 보였다("Where were we?가 내 문장이라고 뜬다").
//
// 338에서 두 번 더 고쳤다. 먼저 '직접 쓴 문장'이라 적었더니 보는 사람이 쓴
// 것처럼 읽혔다. 그래서 칩을 아예 뺐더니 이번에는 남의 문장 카드만 칩이 없어
// 어색했다(사용자). 그래서 '공유 문장'이라 적는다. 내 것은 '내 문장' 그대로라
// 두 말이 짝을 이룬다.
//
// 주제 값 자체는 바꾸지 않는다(이미 올라간 문장들이 그 값을 들고 있다).
// 보여 줄 때만 보는 사람에 따라 고른다.

/// 직접 적은 문장에 기본으로 붙는 주제. 저장할 때 쓰는 값이다.
const String myOwnSentenceTopic = '내 문장';

/// 남이 올린, 주제를 고르지 않은 문장에 붙이는 말.
const String sharedSentenceTopic = '공유 문장';

/// [topic]을 화면에 보여 줄 말.
///
/// [mine]은 보는 사람이 그 문장을 올린 사람인지. 일상·여행처럼 고른 주제는
/// 누가 보든 그대로 보여 준다. 고른 주제가 없으면 내 것은 '내 문장',
/// 남의 것은 '공유 문장'이다.
String sentenceTopicLabel(String topic, {required bool mine}) {
  final value = topic.trim();
  if (value.isEmpty || value == myOwnSentenceTopic) {
    return mine ? myOwnSentenceTopic : sharedSentenceTopic;
  }
  return value;
}
