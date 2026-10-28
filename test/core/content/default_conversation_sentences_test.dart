import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/default_conversation_sentences.dart';

void main() {
  test('기본 회화는 영어, 일본어, 중국어별로 열 문장을 제공한다', () {
    for (final language in ['영어', '일본어', '중국어']) {
      final sentences = defaultSentencesFor(language);
      expect(sentences, hasLength(10));
      expect(sentences.every((sentence) => sentence.text.isNotEmpty), isTrue);
      expect(sentences.every((sentence) => sentence.translation.isNotEmpty),
          isTrue);
    }

    expect(
      defaultConversationSentences.map((sentence) => sentence.id).toSet(),
      hasLength(defaultConversationSentences.length),
    );
  });
}
