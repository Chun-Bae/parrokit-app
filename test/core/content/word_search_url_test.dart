// 단어를 웹에서 찾아볼 주소(5차, 사용자 요청).
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/word_search_url.dart';

void main() {
  test('사전이 있는 언어는 그 언어 사전으로 보낸다', () {
    expect(wordSearchUrl(language: '영어', word: 'huge'),
        'https://en.dict.naver.com/#/search?query=huge');
    expect(wordSearchUrl(language: '일본어', word: '食べる'),
        startsWith('https://ja.dict.naver.com/#/search?query='));
  });

  test('모르는 언어는 검색으로 보내고 언어 이름을 함께 넣는다', () {
    final url = wordSearchUrl(language: '스와힐리어', word: 'habari');
    expect(url, startsWith('https://www.google.com/search?q=habari'));
    expect(url, contains(Uri.encodeQueryComponent('스와힐리어 뜻')));
  });

  test('띄어쓰기와 특수문자가 있어도 주소가 깨지지 않는다', () {
    final url = wordSearchUrl(language: '영어', word: 'figure out & go');
    expect(url, isNot(contains(' ')));
    expect(url, contains(Uri.encodeQueryComponent('figure out & go')));
  });

  test('단어가 비면 주소를 만들지 않는다', () {
    expect(wordSearchUrl(language: '영어', word: '   '), '');
  });

  test('제목에 어느 단어를 찾는지 적는다', () {
    expect(wordSearchTitle('huge'), contains('huge'));
  });
}
