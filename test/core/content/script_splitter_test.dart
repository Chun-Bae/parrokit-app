import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/script_splitter.dart';

void main() {
  test('시간 표시와 소리 설명을 지우고 문장부호로 나눈다', () {
    const raw =
        '0:01\n[Music]\nHello there! How are you?\n0:05\nI am fine. (applause)\n';
    expect(ScriptSplitter.split(raw),
        ['Hello there!', 'How are you?', 'I am fine.']);
  });

  test('문장부호가 거의 없는 자막 조각은 줄 단위로 나눈다', () {
    const raw =
        '1:02\nhello everyone\n1:04\nwelcome back\n1:06\nto my channel\n';
    expect(ScriptSplitter.split(raw),
        ['hello everyone', 'welcome back', 'to my channel']);
  });

  test('줄에 걸쳐 끊긴 문장을 이어 붙이고 중복은 한 번만 남긴다', () {
    const raw =
        'I was wondering if\nyou could help me.\nI was wondering if\nyou could help me.';
    expect(
        ScriptSplitter.split(raw), ['I was wondering if you could help me.']);
  });

  test('시:분:초 형식과 빈 입력도 처리한다', () {
    expect(ScriptSplitter.split('1:02:03 Good morning.'), ['Good morning.']);
    expect(ScriptSplitter.split('  \n\n'), isEmpty);
  });

  test('일본어·중국어 문장부호로도 나눈다', () {
    expect(ScriptSplitter.split('こんにちは。元気ですか？'), ['こんにちは。', '元気ですか？']);
  });
}
