// 음성 만들기 실패도 예외 글 대신 사람 말로(5차 311).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/content-studio/tts/presentation/tts_error_text.dart';

void main() {
  test('패롯이 모자라면 그렇게 말한다', () {
    // 서버(wallet.ts)는 '보유하신 패롯이 부족합니다.'를 준다. 앞에 붙는
    // `[firebase_functions/failed-precondition]`까지 그대로 보였다.
    const serverSaid = '[firebase_functions/failed-precondition] '
        '보유하신 패롯이 부족합니다.';
    expect(ttsErrorText(serverSaid), '패롯이 모자라요. 더 채우고 다시 해 주세요.');
  });

  test('인터넷이 끊긴 것이면 그렇게 말한다', () {
    expect(ttsErrorText('SocketException: Failed host lookup'),
        contains('인터넷'));
    expect(ttsErrorText('[firebase_functions/unavailable] no network'),
        contains('인터넷'));
  });

  test('그 밖에는 무엇이 안 됐는지로 말한다', () {
    expect(ttsErrorText(Exception('boom')),
        '음성을 만들지 못했어요. 잠시 뒤 다시 해 주세요.');
  });

  test('로그인이 풀린 것이면 그렇게 말한다', () {
    expect(ttsErrorText('[firebase_functions/unauthenticated] no auth'),
        contains('로그인'));
  });

  test('TTS Provider는 예외 글을 그대로 담지 않는다', () {
    final code = File(
            'lib/features/content-studio/tts/presentation/providers/tts_provider.dart')
        .readAsStringSync();
    expect(code.contains('_errorMessage = e.toString()'), isFalse);
    expect(code, contains('ttsErrorText(e)'));
  });
}
