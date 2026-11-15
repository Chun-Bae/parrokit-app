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
    expect(exchange, contains('가진 패롯이 모자라요.'));
    expect(exchange, contains('1,000개 단위로만 바꿀 수 있어요.'));

    final signUp =
        File('lib/features/auth/sign-up/sign_up_screen.dart').readAsStringSync();
    expect(signUp, contains('6자 이상이어야 해요.'));
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
