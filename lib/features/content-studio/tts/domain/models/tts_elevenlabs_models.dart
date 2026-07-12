class TtsElevenLabsVoice {
  final String id;
  final String name;
  final String category;

  /// ElevenLabs voice의 `labels` 메타데이터.
  ///
  /// `language`와 `accent`는 서로 다른 라벨이다: `language`는 이 보이스가
  /// 실제로 학습된 언어(ISO 639-1 코드, 예: ja/ko)를 뜻하고, `accent`는
  /// 영어를 말할 때의 억양 변형(american/british 등)을 뜻한다. 원어민
  /// 보이스는 보통 `accent`가 아니라 `language`로 태그된다.
  final String? language;
  final String? gender;
  final String? age;
  final String? accent;
  final String? tone;
  final String? useCase;

  const TtsElevenLabsVoice({
    required this.id,
    required this.name,
    required this.category,
    this.language,
    this.gender,
    this.age,
    this.accent,
    this.tone,
    this.useCase,
  });

  factory TtsElevenLabsVoice.fromJson(Map<String, dynamic> json) {
    final labels =
        (json['labels'] as Map?)?.cast<String, dynamic>() ?? const {};
    return TtsElevenLabsVoice(
      id: (json['voice_id'] ?? json['voiceId']) as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? '',
      language: labels['language'] as String?,
      gender: labels['gender'] as String?,
      age: labels['age'] as String?,
      accent: labels['accent'] as String?,
      tone: labels['description'] as String?,
      useCase: labels['use_case'] as String?,
    );
  }

  /// 성별/연령/톤/용도를 자연스러운 한 줄 설명으로 조합합니다. 언어/억양은 별도로
  /// [originLabel]에서 다루므로 여기엔 포함하지 않습니다.
  String get friendlyDescription {
    final parts = <String>[];

    final genderKo = _translateGender(gender);
    final ageKo = _translateAge(age);
    if (genderKo != null || ageKo != null) {
      parts.add([ageKo, genderKo].whereType<String>().join(' '));
    }

    if (tone != null && tone!.isNotEmpty) parts.add('$tone 톤');

    final useCaseKo = _translateUseCase(useCase);
    if (useCaseKo != null) parts.add('$useCaseKo에 적합');

    return parts.isEmpty ? category : parts.join(' · ');
  }

  /// 학습된 언어(한국어 표기). 라벨이 없거나 인식하지 못하면 null.
  String? get languageLabel => _translateLanguageCode(language);

  /// 원 억양(한국어 표기). 라벨이 없거나 인식하지 못하면 null.
  ///
  /// ElevenLabs 다국어 모델은 화자의 원 억양을 다른 언어로 생성할 때도 그대로
  /// 유지하는 특성이 있어, 학습 대상 언어 발음이 중요한 경우 참고가 필요합니다.
  String? get accentLabel => _translateAccent(accent);

  /// 필터/드롭다운에서 쓰는 통합 구분값. `accent`가 있으면 그걸 우선합니다.
  ///
  /// 영어권 보이스는 `language: en`과 `accent: australian`처럼 둘 다 붙는
  /// 경우가 많은데, 이때는 더 구체적인 `accent`(호주식)가 의미 있는 정보이고
  /// `language`(영어식)는 사실상 항상 en이라 정보가 없습니다. `accent`가
  /// 없는 원어민 보이스(일본어/한국어 등)에 한해서만 `language`로 대체합니다.
  String? get originLabel => accentLabel ?? languageLabel;

  /// [originLabel]과 같은 우선순위로 매칭되는 국기 이모지. 없으면 null.
  String? get originFlag =>
      _flagForAccent(accent) ?? _flagForLanguageCode(language);
}

/// accent 라벨과 동일한 "-식" 형태로 통일해서 반환합니다 (예: 일본식, 한국식).
String? _translateLanguageCode(String? value) => switch (value) {
      'ko' => '한국식',
      'ja' => '일본식',
      'en' => '영어식',
      'zh' => '중국식',
      'es' => '스페인식',
      'fr' => '프랑스식',
      'de' => '독일식',
      'it' => '이탈리아식',
      'pt' => '포르투갈식',
      'ru' => '러시아식',
      'ar' => '아랍식',
      'hi' => '힌디식',
      'tr' => '터키식',
      'nl' => '네덜란드식',
      'pl' => '폴란드식',
      'vi' => '베트남식',
      'id' => '인도네시아식',
      _ => null,
    };

String? _translateGender(String? value) => switch (value) {
      'male' => '남성',
      'female' => '여성',
      'non-binary' || 'non_binary' => '논바이너리',
      _ => null,
    };

String? _translateAge(String? value) => switch (value) {
      'young' => '청년',
      'middle_aged' || 'middle-aged' => '중년',
      'old' => '노년',
      _ => null,
    };

String? _translateAccent(String? value) => switch (value) {
      'american' => '미국식',
      'british' => '영국식',
      'australian' => '호주식',
      'irish' => '아일랜드식',
      'african' => '아프리카식',
      'indian' => '인도식',
      'canadian' => '캐나다식',
      'french' => '프랑스식',
      'german' => '독일식',
      'spanish' => '스페인식',
      'italian' => '이탈리아식',
      'russian' => '러시아식',
      'portuguese' => '포르투갈식',
      'turkish' => '터키식',
      'japanese' => '일본식',
      'korean' => '한국식',
      _ => null,
    };

String? _flagForAccent(String? value) => switch (value) {
      'american' => '🇺🇸',
      'british' => '🇬🇧',
      'australian' => '🇦🇺',
      'irish' => '🇮🇪',
      'indian' => '🇮🇳',
      'canadian' => '🇨🇦',
      'french' => '🇫🇷',
      'german' => '🇩🇪',
      'spanish' => '🇪🇸',
      'italian' => '🇮🇹',
      'russian' => '🇷🇺',
      'portuguese' => '🇵🇹',
      'turkish' => '🇹🇷',
      'japanese' => '🇯🇵',
      'korean' => '🇰🇷',
      _ => null,
    };

String? _flagForLanguageCode(String? value) => switch (value) {
      'ko' => '🇰🇷',
      'ja' => '🇯🇵',
      'en' => '🇺🇸',
      'zh' => '🇨🇳',
      'es' => '🇪🇸',
      'fr' => '🇫🇷',
      'de' => '🇩🇪',
      'it' => '🇮🇹',
      'pt' => '🇵🇹',
      'ru' => '🇷🇺',
      'ar' => '🇸🇦',
      'hi' => '🇮🇳',
      'tr' => '🇹🇷',
      'nl' => '🇳🇱',
      'pl' => '🇵🇱',
      'vi' => '🇻🇳',
      'id' => '🇮🇩',
      _ => null,
    };

String? _translateUseCase(String? value) => switch (value) {
      'narration' => '내레이션',
      'conversational' => '일상 대화',
      'characters_animation' || 'characters' => '캐릭터 연기',
      'social_media' => '소셜미디어 콘텐츠',
      'entertainment_tv' => '방송/엔터테인먼트',
      'informative_educational' => '교육 콘텐츠',
      'advertisement' => '광고',
      'news' => '뉴스',
      _ => null,
    };

class TtsElevenLabsModel {
  final String id;
  final String name;
  final String description;

  /// 이 모델 기준 1패롯이 커버하는 글자 수 (70% 마진 기준).
  final int charsPerParrot;

  const TtsElevenLabsModel({
    required this.id,
    required this.name,
    required this.description,
    required this.charsPerParrot,
  });
}

const List<TtsElevenLabsModel> elevenLabsModels = [
  TtsElevenLabsModel(
    id: 'eleven_multilingual_v2',
    name: 'Multilingual v2',
    description: '가장 자연스럽고 감정 표현이 풍부한 고품질 모델. 생성 속도는 느린 편',
    charsPerParrot: 20,
  ),
  TtsElevenLabsModel(
    id: 'eleven_turbo_v2_5',
    name: 'Turbo v2.5',
    description: 'v2보다 품질은 약간 낮지만 3배 빠르고 비용도 절반. 실시간 대화에 적합',
    charsPerParrot: 40,
  ),
];
