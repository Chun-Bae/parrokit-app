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

/// 주제를 고르지 않은 상태. 칩 목록의 첫 칸이고, 거르지 않는다는 뜻이다.
const String allSentenceTopics = '전체';

/// 주제를 거르지 않았는데도 공유된 문장이 하나도 없을 때.
const String noSharedSentenceMessage = '아직 공유된 문장이 없어요. 내 문장을 공유해 보세요.';

/// 고른 주제로 걸러 비었을 때 되돌아가는 길.
const String showAllSentenceTopicsLabel = '모든 주제 보기';

/// 공유 문장이 하나도 안 보일 때 할 말.
///
/// [category]는 고른 주제 칩, [anyShared]는 주제를 떠나 공유된 문장이 하나라도
/// 있는지다.
///
/// 전에는 걸러서 빈 것과 정말 하나도 없는 것을 가리지 않고 둘 다 '아직 공유된
/// 문장이 없어요. 내 문장을 공유해 보세요.'라고 했다. '일상'을 고르면 다른
/// 주제에는 문장이 있는데도 아무도 공유하지 않은 것처럼 읽혔고, 갈 길도 직접
/// 공유하라는 것 하나뿐이라 주제를 되돌리면 된다는 걸 알려 주지 않았다(5차 500).
String sharedSentencesEmptyMessage({
  required String category,
  required bool anyShared,
}) {
  final topic = category.trim();
  if (!anyShared || topic.isEmpty || topic == allSentenceTopics) {
    return noSharedSentenceMessage;
  }
  return "'$topic' 주제에 공유된 문장이 아직 없어요.";
}
