// 이름 뒤 조사를 받침에 맞춰 고른다(5차).
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/utils/korean_josa.dart';

void main() {
  test('받침에 맞춰 을/를·이/가', () {
    expect(eulReul('여행'), '여행을');
    expect(eulReul('일본어'), '일본어를');
    expect(iGa('단어'), '단어가');
    expect(iGa('문장'), '문장이');
  });

  test('으로/로: 받침 없음·ㄹ 받침은 로', () {
    expect(euro('여행'), '여행으로');
    expect(euro('오사카'), '오사카로');
    expect(euro('서울'), '서울로');
    expect(euro("'일본'"), "'일본'으로");
  });

  test('숫자는 읽는 소리로, 영어 등은 두 가지를 함께', () {
    expect(euro('폴더 2'), '폴더 2로');
    expect(euro('폴더 3'), '폴더 3으로');
    expect(euro('폴더 1'), '폴더 1로');
    expect(euro('travel'), 'travel(으)로');
    expect(eulReul('meet'), 'meet을(를)');
    expect(iGa(''), '이(가)');
  });
}
