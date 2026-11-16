// 자막 만드는 중에도 저장이 왜 안 되는지 적는다(5차 318).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/content-studio/captioning/domain/validators/clip_validator.dart';

void main() {
  test('자막 만드는 중 안내는 무엇을 기다리는지 말한다', () {
    expect(ClipValidator.sttRunningMessage, contains('자막'));
    expect(ClipValidator.sttRunningMessage, contains('저장'));
  });

  test('화면이 그 말을 쓴다', () {
    // 전에는 isSttProcessing일 때 단추만 꺼지고 아래 글이 없었다.
    final code = File(
            'lib/features/content-studio/captioning/presentation/screens/captioning_screen.dart')
        .readAsStringSync()
        .replaceAll(RegExp(r'\s+'), ' ');
    expect(code, contains('vm.isSttProcessing ? ClipValidator.sttRunningMessage'));
    expect(code, contains("ValueKey('save-blocked-reason')"));
  });

  test('막는 까닭은 빠진 것부터 차례로 말한다', () {
    expect(
        ClipValidator.blockedReason(filePath: '', folder: '', title: ''),
        ClipValidator.noFileMessage);
    expect(
        ClipValidator.blockedReason(
            filePath: '/tmp/a.mp4', folder: '', title: ''),
        isNot(ClipValidator.noFileMessage));
    expect(
        ClipValidator.blockedReason(
            filePath: '/tmp/a.mp4', folder: '일상', title: '제목'),
        isNull,
        reason: '구간을 주지 않으면 구간은 보지 않는다');
  });
}
