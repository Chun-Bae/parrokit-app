// 스튜디오(영상·자막·음성·챗봇) 화면 말투도 앱과 맞춘다(5차 UX 점검 2).
//
// 개발자용 예외 메시지(throw)는 화면에 그대로 뜨지 않으므로 뺀다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _formal = RegExp(r"'[^']*(습니다|습니까)[^']*'");

/// 주석과 개발자용 예외는 빼고, 화면에 보이는 글만 남긴다.
List<String> _uiLines(File file) => file
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .where((line) =>
        !line.contains('throw ') &&
        !line.contains('ArgumentError') &&
        !line.contains('StateError'))
    .toList();

void main() {
  test("스튜디오 화면 글에 '~습니다' 말투가 없다", () {
    final offenders = <String>[];
    for (final entity
        in Directory('lib/features/content-studio').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      for (final line in _uiLines(entity)) {
        final found = _formal.firstMatch(line)?.group(0);
        if (found != null) offenders.add('${entity.path}: $found');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('환전소와 가입 화면도 같은 말투를 쓴다', () {
    final exchange = File(
            'lib/features/settings/more/presentation/exchange_screen.dart')
        .readAsStringSync();
    // 막는 말은 이제 exchangeInputProblem 한 곳에서 나온다(5차 365).
    expect(exchange, contains('가진 \$name보다 많아요'));
    expect(exchange, contains('개 단위로 바꿀 수 있어요'));
    expect(exchange, contains('환전했어요.'));

    // 415에서 로그인·가입·비밀번호 찾기의 입력 안내를 한 곳으로 모았다.
    final authTexts =
        File('lib/features/auth/auth_input_text.dart').readAsStringSync();
    expect(authTexts, contains('6자 이상이어야 해요.'));
    expect(authTexts, contains('적어 주세요'));
    final signUp =
        File('lib/features/auth/sign-up/sign_up_screen.dart').readAsStringSync();
    expect(signUp, contains('passwordShortMessage'));
  });

  test('자주 보는 글은 앱 말투로 바뀌어 있다', () {
    final texts = File(
            'lib/features/content-studio/tts/presentation/screens/tts_screen.dart')
        .readAsStringSync();
    expect(texts, contains('음성 파일을 저장했어요.'));

    final video = File(
            'lib/features/content-studio/video/presentation/video_screen.dart')
        .readAsStringSync();
    expect(video, contains('아직 저장한 영상이 없어요.'));
  });
}
