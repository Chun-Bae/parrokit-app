// 공개된 문장과 내 문장을 맞춰 보는 규칙 한 곳(5차 364).
//
// 보관함 둘러보기와 홈 '요즘 뜨는 문장'이 같은 규칙을 각자 적어 두고 있었다.
// 한쪽만 고치면 같은 문장이 한 화면에서는 '저장됨', 다른 화면에서는 아닌 것으로
// 보인다. 저장·저장 해제·루틴 켜기가 모두 이 규칙을 쓰므로 한 곳에 둔다.

import 'package:parrokit/core/content/default_conversation_sentences.dart';
import 'package:parrokit/core/content/shared_sentence_repository.dart';

/// [shared]와 같은 내 문장. 없으면 null.
///
/// 같은 것으로 보는 경우는 셋이다.
/// - 내가 올린 문장이라 문서가 같을 때(id가 같다)
/// - 둘러보기에서 저장한 사본일 때(sourceSharedId가 가리킨다)
/// - 같은 언어에 같은 글일 때(앞뒤 공백은 뺀다)
DefaultConversationSentence? savedCopyOfShared(
  Iterable<DefaultConversationSentence> mine,
  SharedSentence shared,
) {
  for (final item in mine) {
    if (item.id == shared.id ||
        item.sourceSharedId == shared.id ||
        (item.language == shared.language &&
            item.text.trim() == shared.text.trim())) {
      return item;
    }
  }
  return null;
}
