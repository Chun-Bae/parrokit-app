class DefaultConversationSentence {
  const DefaultConversationSentence({
    required this.id,
    required this.language,
    required this.text,
    required this.translation,
    required this.pronunciation,
    required this.topic,
  });

  final String id;
  final String language;
  final String text;
  final String translation;
  final String pronunciation;
  final String topic;
}

const defaultConversationSentences = <DefaultConversationSentence>[
  DefaultConversationSentence(
    id: 'basic-en-001',
    language: '영어',
    text: 'Hello there!',
    translation: '안녕하세요!',
    pronunciation: '헬로 데어',
    topic: '인사',
  ),
  DefaultConversationSentence(
    id: 'basic-en-002',
    language: '영어',
    text: 'How was your day?',
    translation: '오늘 하루 어땠어요?',
    pronunciation: '하우 워즈 유어 데이',
    topic: '일상',
  ),
  DefaultConversationSentence(
    id: 'basic-en-003',
    language: '영어',
    text: 'Can I get a coffee?',
    translation: '커피 한 잔 주세요.',
    pronunciation: '캔 아이 겟 어 커피',
    topic: '카페',
  ),
  DefaultConversationSentence(
    id: 'basic-ja-001',
    language: '일본어',
    text: 'こんにちは！',
    translation: '안녕하세요!',
    pronunciation: '곤니치와',
    topic: '인사',
  ),
  DefaultConversationSentence(
    id: 'basic-ja-002',
    language: '일본어',
    text: '今日はどうでしたか？',
    translation: '오늘 하루 어땠어요?',
    pronunciation: '쿄오와 도오데시타카',
    topic: '일상',
  ),
  DefaultConversationSentence(
    id: 'basic-ja-003',
    language: '일본어',
    text: 'コーヒーをください。',
    translation: '커피 한 잔 주세요.',
    pronunciation: '코오히이오 쿠다사이',
    topic: '카페',
  ),
  DefaultConversationSentence(
    id: 'basic-zh-001',
    language: '중국어',
    text: '你好！',
    translation: '안녕하세요!',
    pronunciation: 'Nǐ hǎo',
    topic: '인사',
  ),
  DefaultConversationSentence(
    id: 'basic-zh-002',
    language: '중국어',
    text: '你今天过得怎么样？',
    translation: '오늘 하루 어땠어요?',
    pronunciation: 'Nǐ jīntiān guò de zěnmeyàng',
    topic: '일상',
  ),
  DefaultConversationSentence(
    id: 'basic-zh-003',
    language: '중국어',
    text: '请给我一杯咖啡。',
    translation: '커피 한 잔 주세요.',
    pronunciation: 'Qǐng gěi wǒ yì bēi kāfēi',
    topic: '카페',
  ),
  DefaultConversationSentence(
    id: 'basic-en-004',
    language: '영어',
    text: 'Nice to meet you.',
    translation: '만나서 반가워요.',
    pronunciation: '나이스 투 밋 유',
    topic: '인사',
  ),
  DefaultConversationSentence(
    id: 'basic-en-005',
    language: '영어',
    text: 'Thank you so much.',
    translation: '정말 고마워요.',
    pronunciation: '땡큐 쏘 머치',
    topic: '감사',
  ),
  DefaultConversationSentence(
    id: 'basic-en-006',
    language: '영어',
    text: 'Excuse me, where is the station?',
    translation: '실례합니다, 역이 어디예요?',
    pronunciation: '익스큐즈 미 웨어 이즈 더 스테이션',
    topic: '여행',
  ),
  DefaultConversationSentence(
    id: 'basic-en-007',
    language: '영어',
    text: 'How much is this?',
    translation: '이거 얼마예요?',
    pronunciation: '하우 머치 이즈 디스',
    topic: '쇼핑',
  ),
  DefaultConversationSentence(
    id: 'basic-en-008',
    language: '영어',
    text: 'I’m just looking around.',
    translation: '그냥 둘러보는 중이에요.',
    pronunciation: '아임 저스트 루킹 어라운드',
    topic: '쇼핑',
  ),
  DefaultConversationSentence(
    id: 'basic-en-009',
    language: '영어',
    text: 'Could you say that again?',
    translation: '다시 한번 말해 주실래요?',
    pronunciation: '쿠쥬 세이 댓 어게인',
    topic: '대화',
  ),
  DefaultConversationSentence(
    id: 'basic-en-010',
    language: '영어',
    text: 'See you tomorrow.',
    translation: '내일 봐요.',
    pronunciation: '씨 유 터머로우',
    topic: '인사',
  ),
  DefaultConversationSentence(
    id: 'basic-ja-004',
    language: '일본어',
    text: 'はじめまして。',
    translation: '처음 뵙겠습니다.',
    pronunciation: '하지메마시테',
    topic: '인사',
  ),
  DefaultConversationSentence(
    id: 'basic-ja-005',
    language: '일본어',
    text: 'ありがとうございます。',
    translation: '감사합니다.',
    pronunciation: '아리가토오 고자이마스',
    topic: '감사',
  ),
  DefaultConversationSentence(
    id: 'basic-ja-006',
    language: '일본어',
    text: 'すみません、駅はどこですか？',
    translation: '실례합니다, 역이 어디예요?',
    pronunciation: '스미마센 에키와 도코데스카',
    topic: '여행',
  ),
  DefaultConversationSentence(
    id: 'basic-ja-007',
    language: '일본어',
    text: 'これはいくらですか？',
    translation: '이거 얼마예요?',
    pronunciation: '코레와 이쿠라데스카',
    topic: '쇼핑',
  ),
  DefaultConversationSentence(
    id: 'basic-ja-008',
    language: '일본어',
    text: 'ちょっと見ているだけです。',
    translation: '그냥 보고 있는 거예요.',
    pronunciation: '춋토 미테이루다케데스',
    topic: '쇼핑',
  ),
  DefaultConversationSentence(
    id: 'basic-ja-009',
    language: '일본어',
    text: 'もう一度言ってください。',
    translation: '다시 한번 말해 주세요.',
    pronunciation: '모오 이치도 잇테 쿠다사이',
    topic: '대화',
  ),
  DefaultConversationSentence(
    id: 'basic-ja-010',
    language: '일본어',
    text: 'また明日。',
    translation: '내일 봐요.',
    pronunciation: '마타 아시타',
    topic: '인사',
  ),
  DefaultConversationSentence(
    id: 'basic-zh-004',
    language: '중국어',
    text: '很高兴认识你。',
    translation: '만나서 반가워요.',
    pronunciation: 'Hěn gāoxìng rènshi nǐ',
    topic: '인사',
  ),
  DefaultConversationSentence(
    id: 'basic-zh-005',
    language: '중국어',
    text: '非常感谢。',
    translation: '정말 감사합니다.',
    pronunciation: 'Fēicháng gǎnxiè',
    topic: '감사',
  ),
  DefaultConversationSentence(
    id: 'basic-zh-006',
    language: '중국어',
    text: '请问，车站在哪里？',
    translation: '실례지만 역이 어디예요?',
    pronunciation: 'Qǐngwèn chēzhàn zài nǎlǐ',
    topic: '여행',
  ),
  DefaultConversationSentence(
    id: 'basic-zh-007',
    language: '중국어',
    text: '这个多少钱？',
    translation: '이거 얼마예요?',
    pronunciation: 'Zhège duōshao qián',
    topic: '쇼핑',
  ),
  DefaultConversationSentence(
    id: 'basic-zh-008',
    language: '중국어',
    text: '我只是随便看看。',
    translation: '그냥 둘러보는 거예요.',
    pronunciation: 'Wǒ zhǐshì suíbiàn kànkan',
    topic: '쇼핑',
  ),
  DefaultConversationSentence(
    id: 'basic-zh-009',
    language: '중국어',
    text: '请再说一遍。',
    translation: '다시 한번 말해 주세요.',
    pronunciation: 'Qǐng zài shuō yí biàn',
    topic: '대화',
  ),
  DefaultConversationSentence(
    id: 'basic-zh-010',
    language: '중국어',
    text: '明天见。',
    translation: '내일 봐요.',
    pronunciation: 'Míngtiān jiàn',
    topic: '인사',
  ),
];

List<DefaultConversationSentence> defaultSentencesFor(String language) =>
    defaultConversationSentences
        .where((sentence) => sentence.language == language)
        .toList(growable: false);

DefaultConversationSentence? defaultSentenceForText(
  String language,
  String text,
) {
  for (final sentence in defaultConversationSentences) {
    if (sentence.language == language && sentence.text == text) return sentence;
  }
  return null;
}
