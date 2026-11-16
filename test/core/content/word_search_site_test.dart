// 단어를 어디서 찾을지 고를 수 있다(5차, 사용자 요청).

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/word_search_url.dart';

void main() {
  test('고른 곳으로 주소를 만든다', () {
    expect(
        wordSearchUrl(
            language: '영어', word: 'huge', site: WordSearchSite.naver),
        contains('en.dict.naver.com'));
    expect(
        wordSearchUrl(language: '영어', word: 'huge', site: WordSearchSite.daum),
        contains('dic.daum.net'));
    expect(
        wordSearchUrl(
            language: '영어', word: 'huge', site: WordSearchSite.google),
        contains('google.com/search'));
  });

  test('고른 사전에 그 언어가 없으면 구글로 보낸다', () {
    // 다음 사전에는 프랑스어가 없다. 빈 화면 대신 검색 결과를 띄운다.
    final url = wordSearchUrl(
        language: '프랑스어', word: 'grand', site: WordSearchSite.daum);
    expect(url, contains('google.com/search'));
    expect(wordSearchSiteHasLanguage(WordSearchSite.daum, '프랑스어'), isFalse);
    expect(wordSearchSiteHasLanguage(WordSearchSite.naver, '프랑스어'), isTrue);
    expect(wordSearchSiteHasLanguage(WordSearchSite.google, '프랑스어'), isTrue);
  });

  test('고르는 메뉴에 그 언어 사전이 없다는 것을 적는다', () {
    expect(wordSearchSiteLabel(WordSearchSite.naver, '영어'), '네이버 사전');
    expect(wordSearchSiteLabel(WordSearchSite.daum, '프랑스어'),
        contains('이 언어는 구글로'));
  });

  test('저장한 값을 다시 읽고, 모르는 값은 네이버로', () {
    expect(WordSearchSite.fromStorage('daum'), WordSearchSite.daum);
    expect(WordSearchSite.fromStorage('google'), WordSearchSite.google);
    expect(WordSearchSite.fromStorage(null), WordSearchSite.naver);
    expect(WordSearchSite.fromStorage('없는값'), WordSearchSite.naver);
  });

  test('단어가 비면 주소를 만들지 않는다', () {
    expect(wordSearchUrl(language: '영어', word: '  '), isEmpty);
  });
}
