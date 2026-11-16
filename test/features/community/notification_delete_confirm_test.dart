// 알림 '모두 지우기'는 되돌릴 수 없다. 묻고 지우는지, 안내 말이 앱 말투인지
// 소스에서 확인한다(화면을 띄우려면 Firebase 메시징까지 필요해서 글만 본다).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _screen =
    'lib/features/community/notification/presentation/community_notification_screen.dart';
const _list =
    'lib/features/community/notification/presentation/sections/community_notification_list_section.dart';

String _read(String path) => File(path).readAsStringSync();

/// 주석 줄은 뺀다. 예전 글을 설명하는 주석이 검사에 걸리지 않게 한다.
String _code(String path) => _read(path)
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('모두 지우기는 묻고 나서 지운다', () {
    final code = _code(_screen);
    expect(code, contains('알림을 모두 지울까요?'));
    expect(code, contains('지우면 되돌릴 수 없어요.'));
    // 메뉴에서 바로 지우지 않는다. 확인을 거치는 함수만 부른다.
    expect(code, contains('_confirmDeleteAll'));
    final menuCall = RegExp(
        r'onTap: provider\.hasNotifications\s*\n\s*\? \(\) => _confirmDeleteAll');
    expect(menuCall.hasMatch(code), isTrue, reason: '메뉴의 모두 지우기가 확인 창을 거쳐야 한다');
  });

  test('확인 창 버튼 이름이 하는 일과 같다', () {
    final code = _code(_screen);
    expect(code, contains("Text('모두 지우기'"));
    expect(code, contains("Text('취소'"));
  });

  test('알림 화면 안내는 지우기·~어요로 적는다', () {
    for (final path in [_screen, _list]) {
      final code = _code(path);
      expect(code, isNot(contains('삭제했습니다')), reason: path);
      expect(code, isNot(contains('삭제합니다')), reason: path);
    }
    expect(_code(_screen), contains('알림을 모두 지웠어요.'));
    expect(_code(_list), contains('알림을 지웠어요.'));
  });
}
