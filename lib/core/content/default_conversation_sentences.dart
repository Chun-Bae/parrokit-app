class DefaultConversationSentence {
  const DefaultConversationSentence({
    required this.id,
    required this.language,
    required this.text,
    required this.translation,
    required this.pronunciation,
    required this.topic,
    this.author = '',
    this.addedAt,
  });

  final String id;
  final String language;
  final String text;
  final String translation;
  final String pronunciation;
  final String topic;

  /// 문장을 만든(저장한) 사람의 닉네임. 기본 문장이나 오래된 문장은 빈 값.
  final String author;

  /// 내 문장으로 저장·추가한 시각. 기본 문장은 null.
  final DateTime? addedAt;
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
  DefaultConversationSentence(
    id: 'basic-en-011',
    language: '영어',
    text:
        'I was wondering if you could help me find a good place for lunch nearby.',
    translation: '근처에 점심 먹기 좋은 곳을 찾도록 도와주실 수 있을까요?',
    pronunciation: '아이 워즈 원더링 이프 유 쿠드 헬프 미 파인드 어 굿 플레이스 포 런치 니어바이',
    topic: '식사',
  ),
  DefaultConversationSentence(
    id: 'basic-en-012',
    language: '영어',
    text:
        'If it’s okay with you, I’d like to change my reservation to tomorrow evening.',
    translation: '괜찮으시다면 예약을 내일 저녁으로 바꾸고 싶어요.',
    pronunciation: '이프 잇츠 오케이 위드 유 아이드 라이크 투 체인지 마이 레저베이션 투 터머로우 이브닝',
    topic: '예약',
  ),
  DefaultConversationSentence(
    id: 'basic-en-013',
    language: '영어',
    text:
        'I’ve been learning English for a few months, and I’m starting to enjoy speaking it.',
    translation: '몇 달째 영어를 배우고 있는데, 말하는 게 점점 즐거워지고 있어요.',
    pronunciation: '아이브 빈 러닝 잉글리시 포 어 퓨 먼쓰 앤드 아임 스타팅 투 인조이 스피킹 잇',
    topic: '학습',
  ),
  DefaultConversationSentence(
    id: 'basic-ja-011',
    language: '일본어',
    text: '近くでおいしいランチができる場所を教えていただけませんか？',
    translation: '근처에서 맛있는 점심을 먹을 수 있는 곳을 알려 주실 수 있나요?',
    pronunciation: '치카쿠데 오이시이 란치가 데키루 바쇼오 오시에테 이타다케마셍카',
    topic: '식사',
  ),
  DefaultConversationSentence(
    id: 'basic-ja-012',
    language: '일본어',
    text: '差し支えなければ、予約を明日の夜に変更したいのですが。',
    translation: '괜찮으시다면 예약을 내일 밤으로 바꾸고 싶은데요.',
    pronunciation: '사시츠카에나케레바 요야쿠오 아시타노 요루니 헨코오시타이노데스가',
    topic: '예약',
  ),
  DefaultConversationSentence(
    id: 'basic-ja-013',
    language: '일본어',
    text: '数か月前から日本語を勉強していて、話すのが少しずつ楽しくなってきました。',
    translation: '몇 달 전부터 일본어를 공부하고 있는데, 말하는 게 조금씩 즐거워졌어요.',
    pronunciation: '스우카게츠 마에카라 니혼고오 벤쿄오시테이테 하나스노가 스코시즈츠 타노시쿠 낫테키마시타',
    topic: '학습',
  ),
  DefaultConversationSentence(
    id: 'basic-zh-011',
    language: '중국어',
    text: '请问附近有没有适合吃午饭的好地方？',
    translation: '근처에 점심 먹기 좋은 곳이 있나요?',
    pronunciation: 'Qǐngwèn fùjìn yǒu méiyǒu shìhé chī wǔfàn de hǎo dìfang',
    topic: '식사',
  ),
  DefaultConversationSentence(
    id: 'basic-zh-012',
    language: '중국어',
    text: '如果方便的话，我想把预订改到明天晚上。',
    translation: '괜찮으시다면 예약을 내일 저녁으로 바꾸고 싶어요.',
    pronunciation:
        'Rúguǒ fāngbiàn dehuà, wǒ xiǎng bǎ yùdìng gǎi dào míngtiān wǎnshang',
    topic: '예약',
  ),
  DefaultConversationSentence(
    id: 'basic-zh-013',
    language: '중국어',
    text: '我学中文已经几个月了，现在越来越喜欢开口说了。',
    translation: '중국어를 배운 지 몇 달 됐는데, 이제 말하는 게 점점 좋아져요.',
    pronunciation:
        'Wǒ xué Zhōngwén yǐjīng jǐ ge yuè le, xiànzài yuèláiyuè xǐhuan kāikǒu shuō le',
    topic: '학습',
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
