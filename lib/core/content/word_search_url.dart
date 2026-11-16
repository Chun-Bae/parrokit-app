/// 단어를 웹에서 찾아볼 주소.
///
/// 앱 안에서 바로 열 수 있게 검색 결과 주소를 만든다(5차, 사용자 요청).
/// 사전 결과가 가장 잘 나오는 쪽을 쓰고, 모르는 언어는 검색으로 보낸다.
String wordSearchUrl({required String language, required String word}) {
  final query = word.trim();
  if (query.isEmpty) return '';
  final encoded = Uri.encodeQueryComponent(query);

  // 네이버 사전이 있는 언어는 사전으로 바로 보낸다. 뜻·예문·발음이 한 화면에
  // 나와서 구글 검색보다 보기 쉽다.
  const naverDict = {
    '영어': 'en',
    '일본어': 'ja',
    '중국어': 'zh',
    '프랑스어': 'fr',
    '스페인어': 'es',
    '독일어': 'de',
    '베트남어': 'vi',
    '러시아어': 'ru',
  };
  final code = naverDict[language.trim()];
  if (code != null) {
    return 'https://$code.dict.naver.com/#/search?query=$encoded';
  }
  return 'https://www.google.com/search?q=$encoded'
      '+${Uri.encodeQueryComponent('$language 뜻')}';
}

/// 웹에서 찾기 화면의 제목. 어느 단어를 찾는 중인지 적는다.
String wordSearchTitle(String word) => '$word 찾아보기';
