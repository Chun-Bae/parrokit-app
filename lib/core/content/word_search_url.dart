/// 단어를 웹에서 찾아볼 곳과 주소(5차, 사용자 요청).
///
/// 앱 안에서 바로 열 수 있게 검색 결과 주소를 만든다. 어디서 찾을지는
/// 사용자가 고른다(네이버 사전·다음 사전·구글). 고른 값은 `AppConfig`에
/// 저장해서 다음에도 그대로 쓴다.
enum WordSearchSite {
  naver('네이버 사전'),
  daum('다음 사전'),
  google('구글 검색');

  const WordSearchSite(this.label);

  /// 화면에 보여줄 이름.
  final String label;

  /// 저장할 값. 이름이 바뀌어도 예전 값을 읽을 수 있게 따로 둔다.
  String get storageKey => name;

  static WordSearchSite fromStorage(String? value) {
    for (final site in WordSearchSite.values) {
      if (site.storageKey == value) return site;
    }
    return WordSearchSite.naver;
  }
}

/// 네이버 사전이 있는 언어. 뜻·예문·발음이 한 화면에 나와 보기 쉽다.
const Map<String, String> _naverDictCodes = {
  '영어': 'en',
  '일본어': 'ja',
  '중국어': 'zh',
  '프랑스어': 'fr',
  '스페인어': 'es',
  '독일어': 'de',
  '베트남어': 'vi',
  '러시아어': 'ru',
};

/// 다음 사전이 있는 언어.
const Map<String, String> _daumDictCodes = {
  '영어': 'eng',
  '일본어': 'jp',
  '중국어': 'ch',
};

String wordSearchUrl({
  required String language,
  required String word,
  WordSearchSite site = WordSearchSite.naver,
}) {
  final query = word.trim();
  if (query.isEmpty) return '';
  final encoded = Uri.encodeQueryComponent(query);
  final lang = language.trim();

  switch (site) {
    case WordSearchSite.naver:
      final code = _naverDictCodes[lang];
      if (code != null) {
        return 'https://$code.dict.naver.com/#/search?query=$encoded';
      }
    case WordSearchSite.daum:
      final code = _daumDictCodes[lang];
      if (code != null) {
        return 'https://dic.daum.net/search.do?q=$encoded&dic=$code';
      }
    case WordSearchSite.google:
      break;
  }

  // 고른 사전에 그 언어가 없으면 검색으로 보낸다. 빈 화면을 띄우지 않는다.
  return 'https://www.google.com/search?q=$encoded'
      '+${Uri.encodeQueryComponent('$lang 뜻')}';
}

/// 고른 곳에 그 언어의 사전이 있는지. 없으면 구글 검색으로 간다.
bool wordSearchSiteHasLanguage(WordSearchSite site, String language) {
  final lang = language.trim();
  return switch (site) {
    WordSearchSite.naver => _naverDictCodes.containsKey(lang),
    WordSearchSite.daum => _daumDictCodes.containsKey(lang),
    WordSearchSite.google => true,
  };
}

/// 고르는 메뉴에 적을 말. 그 언어 사전이 없으면 그렇게 알려 준다.
String wordSearchSiteLabel(WordSearchSite site, String language) {
  if (wordSearchSiteHasLanguage(site, language)) return site.label;
  return '${site.label} (이 언어는 구글로)';
}

/// 웹에서 찾기 화면의 제목. 어느 단어를 찾는 중인지 적는다.
String wordSearchTitle(String word) => '$word 찾아보기';
