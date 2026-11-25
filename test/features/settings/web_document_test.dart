// 약관·개인정보 처리방침 화면(5차).
//
// 문서는 노션 공개 쪽을 웹뷰로 띄운다. 노션은 로그인하지 않은 사람에게
// 영어 가입 유도 띠를 문서 맨 위에 꽂는다 - 한국어 약관 위에 "You're almost
// there — sign up to start building in Notion today"가 붙고, 심사에서도
// 문서가 아니라 노션 가입 화면처럼 보인다. 시뮬레이터에서 눈으로 확인하고
// 가렸다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final screen = File(
    'lib/features/settings/more/presentation/web_document_screen.dart',
  ).readAsStringSync();

  test('문서를 띄우면 바깥에서 끼워 넣은 것을 가린다', () {
    final finished = screen.indexOf('onPageFinished');
    final hide = screen.indexOf('_hideHostChrome()');
    expect(finished, greaterThan(-1));
    expect(hide, greaterThan(-1), reason: '가리는 것을 부른다');
    expect(finished, lessThan(hide), reason: '다 그려진 뒤에 가린다');
  });

  test('가리는 대상에 가입 유도 띠와 제목줄이 들어 있다', () {
    expect(screen, contains('notion-topbar'));
    expect(screen, contains('sign up to start building'));
    expect(screen, contains('Sign up or login'));
    // 늦게 그려지는 것도 잡는다. 노션은 본문을 비동기로 그린다.
    expect(screen, contains('MutationObserver'));
  });

  test('못 가려도 문서는 보여 준다', () {
    // 클래스 이름은 노션이 언제든 바꾼다. 거기서 터지면 약관이 아예
    // 안 열리므로, 실패는 로그만 남기고 넘어간다.
    final body = screen.substring(screen.indexOf('_hideHostChrome()'));
    expect(body, contains('try {'));
    expect(body, contains('catch (error)'));
  });

  test('앱이 가리키는 문서가 현행 쪽이다', () {
    final info = File(
      'lib/features/settings/more/presentation/sections/info_section.dart',
    ).readAsStringSync();
    // 2025-11-20 옛 쪽에는 약관 자리에 개인정보처리방침이 한 번 더 들어
    // 있었고, 시행일도 비어 있었다(5차).
    expect(info.contains('2025-11-20'), isFalse,
        reason: '옛 문서를 가리키면 안 된다');
    expect(info, contains('421b6c6245ad813f8060ce2b10735561')); // 방침
    expect(info, contains('421b6c6245ad81c48b1ed73a4c6ed4a7')); // 약관
  });
}
