import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/utils/user_error_message.dart';

void main() {
  const fallback = '저장하지 못했어요.';
  String msg(Object e) => userErrorMessage(e, fallback: fallback);

  test('앱이 한국어로 적은 이유는 그대로 보여준다', () {
    expect(msg(StateError('로컬 파일을 찾을 수 없습니다.')), '로컬 파일을 찾을 수 없습니다.');
    expect(msg(ArgumentError('로그인이 필요합니다.')), '로그인이 필요합니다.');
    expect(msg(Exception('편집할 클립을 찾을 수 없습니다.')), '편집할 클립을 찾을 수 없습니다.');
  });

  test('영어 원문·경로·클래스 이름은 보이지 않고 대신 말을 쓴다', () {
    expect(msg(Exception('Final copy failed')), fallback);
    expect(msg(Exception('입력 mp3 파일이 존재하지 않습니다: /var/mobile/a.mp3')), fallback);
    expect(msg(const FormatException('bad')), fallback);
    expect(msg('x' * 10), fallback);
  });

  test('연결 문제는 연결을 확인하라고 한다', () {
    expect(msg(const SocketException('no route')), contains('인터넷 연결'));
    expect(msg(TimeoutException('t')), contains('인터넷 연결'));
  });

  test('Firebase 오류는 영어 문장 대신 코드에 맞는 안내를 한다', () {
    expect(msg(FirebaseAuthException(code: 'user-disabled')), contains('정지된 계정'));
    expect(
        msg(FirebaseAuthException(
            code: 'account-exists-with-different-credential',
            message: 'An account already exists with the same email address')),
        contains('처음 가입한 방법'));
    expect(
        msg(FirebaseAuthException(
            code: 'requires-recent-login',
            message: 'This operation is sensitive')),
        contains('다시 로그인'));
    expect(msg(FirebaseAuthException(code: 'too-many-requests')),
        contains('잠시 뒤'));
    expect(
        msg(FirebaseException(plugin: 'auth', code: 'network-request-failed')),
        contains('인터넷 연결'));
    expect(
        msg(FirebaseException(
            plugin: 'cloud_firestore', code: 'internal', message: 'boom')),
        fallback);
  });
}
