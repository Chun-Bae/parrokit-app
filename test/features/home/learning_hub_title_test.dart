// 학습하기 화면의 제목과 말(5차 462).
//
// 홈에서 '학습하기'를 눌렀는데 화면 제목은 '학습 시작하기'였다.
// 436에서 글쓰기 화면 셋을 고친 것과 같은 결함이다. 한 화면 안에서
// '학습 방법'과 '공부할 영상 찾기'로 말도 갈려 있었다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/home/dashboard/presentation/learning_hub_text.dart';

String _code(String path) => File(path)
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

const _screen = 'lib/features/home/dashboard/presentation/learning_hub_screen.dart';
const _bar = 'lib/features/home/dashboard/presentation/widgets/today_start_bar.dart';

void main() {
  test('화면 제목이 눌러서 들어온 버튼 이름과 같다', () {
    expect(learningHubTitle, '학습하기');
    // 둘 다 한 곳에서 꺼내 쓴다.
    expect(_code(_screen), contains('Text(learningHubTitle'));
    expect(_code(_bar), contains('Text(learningHubTitle'));
  });

  test("예전 제목 '학습 시작하기'가 남아 있지 않다", () {
    for (final path in [_screen, _bar]) {
      expect(_code(path).contains('학습 시작하기'), isFalse, reason: path);
    }
  });

  test("한 화면 안에서 '학습'과 '공부'가 섞이지 않는다", () {
    expect(learningHubMethodTitle, '학습 방법');
    expect(learningHubFindVideoTitle, '학습할 영상 찾기');
    expect(learningHubHeadline, contains('학습해'));
    // 화면 파일에도 '공부'가 남지 않았다.
    expect(_code(_screen).contains('공부'), isFalse);
  });
}
