class DefaultConversationSentence {
  const DefaultConversationSentence({
    required this.id,
    required this.language,
    required this.text,
    required this.translation,
    required this.pronunciation,
    required this.topic,
    this.author = '',
    this.authorId = '',
    this.sourceSharedId = '',
    this.addedAt,
  });

  final String id;
  final String language;
  final String text;
  final String translation;
  final String pronunciation;
  final String topic;

  /// 문장을 만든(저장한) 사람의 닉네임. 오래된 문장은 빈 값.
  final String author;

  /// 문장을 만든 사람의 uid. 내가 만든 문장이면 내 uid, 남의 문장을 저장한 것이면 원작자 uid.
  /// 서버에 올리지 않은 오래된 문장은 빈 값.
  final String authorId;

  /// 남의 공개 문장을 저장해 만든 사본이면 원본 문서 id. 내가 만든 문장은 빈 값.
  final String sourceSharedId;

  /// 내 문장으로 저장·추가한 시각. 모르면 null.
  final DateTime? addedAt;
}

/// 앱이 기본으로 주던 예시 문장은 없앴다(5차, 사용자 결정).
///
/// 앵무새는 이제 내가 저장·추가한 문장만 말한다. 예전 기본 문장에 남아 있는
/// 연습 기록(SentenceActivityStore의 basic-… id)은 그대로 두지만 화면에
/// 나오지 않는다. 이 파일은 문장 모델만 남긴다.
