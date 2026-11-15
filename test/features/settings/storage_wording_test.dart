// 저장 관련 안내 글(5차).
//
// Google Drive는 5차에 걷어냈다(사용자 결정). 그런데 '받아 둔 영상' 설명과
// 처음 켤 때 뜨는 이용 안내에는 "서버나 Google Drive에 옮기세요"가 남아 있어,
// 이제 없는 길을 알려 주고 있었다. '로컬'이라는 내부 말도 섞여 있었다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  /// 주석을 뺀, 화면에 보이는 글만 모은다.
  String visibleText(String path) {
    final lines = File(path).readAsLinesSync();
    return lines
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');
  }

  test('기기 보관분 화면이 없는 길(Drive)을 권하지 않는다', () {
    final text = visibleText(
        'lib/features/settings/more/presentation/storage_cache_management_screen.dart');

    // 이미 Drive에 있는 클립의 자리 이름은 남는다. 권하는 말만 없어야 한다.
    expect(text.contains('Google Drive에 옮기'), isFalse);
    expect(text.contains('서버나 Google Drive에 있는 원본'), isFalse);
  });

  test("안내 글에 '로컬'이라는 내부 말이 없다", () {
    final text = visibleText(
        'lib/features/settings/more/presentation/storage_cache_management_screen.dart');

    expect(text.contains("'로컬'"), isFalse);
  });

  test('이용 안내가 옮길 곳으로 서버만 말한다', () {
    final text = visibleText('lib/core/shared/widgets/tip_dialog.dart');

    expect(text.contains('Google Drive'), isFalse,
        reason: 'Drive로 옮기는 길은 없어졌다');
    expect(text.contains('서버에'), isTrue);
  });
}
