// 체크를 또 눌러도 점수가 다시 올라가면 안 된다(5차, 사용자 신고).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/speech/phrase_recognizer.dart';
import 'package:parrokit/core/speech/presentation/speech_practice_view.dart';

class FakeRecognizer implements PhraseRecognizer {
  bool listening = false;
  void Function(String)? onResult;
  void Function(String?)? onDone;

  @override
  Future<bool> start({
    required String localeId,
    required void Function(String text) onResult,
    required void Function(String? error) onDone,
    void Function(double level)? onLevel,
  }) async {
    this.onResult = onResult;
    this.onDone = onDone;
    return listening = true;
  }

  @override
  Future<void> stop() async => listening = false;
}

const microphone = ValueKey('preview-microphone');
const complete = ValueKey('complete-repeat');

void main() {
  late FakeRecognizer recognizer;
  late List<double?> completions;

  Future<void> open(WidgetTester tester) async {
    recognizer = FakeRecognizer();
    completions = [];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SpeechPracticeView(
          phrase: 'Hello there!',
          localeId: 'en_US',
          recognizer: recognizer,
          enabled: true,
          reduceMotion: true,
          onAttempt: (_) {},
          onBeforeStart: () {},
          onComplete: completions.add,
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('한 번 끝내면 점수가 초기화된다', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(microphone));
    await tester.pump();
    recognizer.onResult!('hello there');
    await tester.pump();
    expect(find.text('100점'), findsOneWidget);

    await tester.tap(find.byKey(complete));
    await tester.pump();

    expect(completions, [1.0]);
    expect(find.byKey(const ValueKey('speech-score')), findsNothing);
    expect(find.byKey(const ValueKey('speech-heard')), findsNothing);
  });

  testWidgets('다시 말하기 전에 또 누르면 넘기지 않고 알린다', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(microphone));
    await tester.pump();
    recognizer.onResult!('hello there');
    await tester.pump();
    await tester.tap(find.byKey(complete));
    await tester.pump();

    await tester.tap(find.byKey(complete));
    await tester.pump();

    expect(completions, [1.0], reason: '두 번째 누름은 아무 일도 하지 않는다');
    expect(find.text('한 번 더 말하고 눌러 주세요.'), findsOneWidget);
  });

  testWidgets('다시 말하면 그 점수로 또 넘길 수 있다', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(microphone));
    await tester.pump();
    recognizer.onResult!('hello there');
    await tester.pump();
    await tester.tap(find.byKey(complete));
    await tester.pump();

    await tester.tap(find.byKey(microphone));
    await tester.pump();
    recognizer.onResult!('hello');
    await tester.pump();
    await tester.tap(find.byKey(complete));
    await tester.pump();

    expect(completions.length, 2);
    expect(completions.last, lessThan(1.0));
  });

  testWidgets('말하지 않고 체크만 누르면 한 번은 점수 없이 넘어간다', (tester) async {
    await open(tester);

    await tester.tap(find.byKey(complete));
    await tester.pump();

    expect(completions, [null]);
  });
}
