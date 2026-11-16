// 문장 상세에서도 따라 말하기를 할 수 있어야 한다(홈 무대와 같은 위젯·기록).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _code(String path) => File(path)
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

const _sheet =
    'lib/features/collection/shell/presentation/widgets/sentence_collection_preview.dart';
const _stage =
    'lib/features/home/dashboard/presentation/stage_preview_screen.dart';

void main() {
  test('문장 상세가 홈과 같은 따라 말하기 위젯을 쓴다', () {
    final sheet = _code(_sheet);
    expect(sheet, contains('SpeechPracticeView('));
    expect(sheet, contains("ValueKey('sentence-speech-practice')"));
    expect(_code(_stage), contains('SpeechPracticeView('));
  });

  test('연습 수·기록·XP를 홈과 같은 저장소에 남긴다', () {
    final sheet = _code(_sheet);
    expect(sheet, contains('SentenceActivityStore.incrementPractice('));
    expect(sheet, contains('PracticeLogStore.add('));
    expect(sheet, contains('addSpeakingXp('));
  });

  test('말하기 전에는 듣던 소리를 멈춘다', () {
    // 읽어 주기는 이제 공유 위젯(SpeakControls)이 들고 있다. 화면은 소리
    // 차례를 가져오는 것으로 멈춘다(AudioFocus가 읽기·반복을 멈춘다, 5차 320).
    expect(_code(_sheet),
        contains('onBeforeStart: () => unawaited(AudioFocus.instance.claim())'));
  });
}
