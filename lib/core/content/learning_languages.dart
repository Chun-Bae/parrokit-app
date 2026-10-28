class LearningLanguage {
  const LearningLanguage({
    required this.code,
    required this.label,
    required this.nativeLabel,
    required this.flag,
    required this.searchTerms,
  });

  final String code;
  final String label;
  final String nativeLabel;
  final String flag;
  final String searchTerms;
}

const availableLearningLanguages = <LearningLanguage>[
  LearningLanguage(
    code: 'en',
    label: '영어',
    nativeLabel: 'English',
    flag: '🇺🇸',
    searchTerms: '영어 english en 미국',
  ),
  LearningLanguage(
    code: 'ja',
    label: '일본어',
    nativeLabel: '日本語',
    flag: '🇯🇵',
    searchTerms: '일본어 japanese ja 日本語',
  ),
  LearningLanguage(
    code: 'zh',
    label: '중국어',
    nativeLabel: '中文',
    flag: '🇨🇳',
    searchTerms: '중국어 chinese zh 中文',
  ),
];

LearningLanguage learningLanguageFor(String label) =>
    availableLearningLanguages.firstWhere(
      (language) => language.label == label,
      orElse: () => availableLearningLanguages.first,
    );
