// 자막 없는 쇼츠에서 자막을 켜면 까닭을 알린다(5차 354).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/collection/clip/shorts/presentation/shorts_texts.dart';

void main() {
  test('안내 글은 무엇이 없는지 말한다', () {
    expect(shortsNoSubtitleHint, contains('자막'));
    expect(shortsNoSubtitleHint, endsWith('없어요.'));
  });

  test('쇼츠 화면이 자막을 켤 때만, 자막이 없을 때만 알린다', () {
    final code = File(
            'lib/features/collection/clip/shorts/presentation/shorts_screen.dart')
        .readAsStringSync()
        .replaceAll(RegExp(r'\s+'), ' ');
    expect(
        code,
        contains(
            'if (enabled && shorts.shorts[current].segments.isEmpty) { showToast(shortsNoSubtitleHint); }'));
  });
}
