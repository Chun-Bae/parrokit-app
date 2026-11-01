import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/my_sentence_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parrokit/core/content/practice_log.dart';
import 'package:parrokit/core/content/sentence_activity_store.dart';
import 'package:parrokit/core/speech/phrase_recognizer.dart';
import 'package:parrokit/features/home/dashboard/presentation/stage_preview_screen.dart';

class FakeRecognizer implements PhraseRecognizer {
  bool available = true;
  bool listening = false;
  String? localeId;
  void Function(String)? onResult;
  void Function(String?)? onDone;
  void Function(double)? onLevel;

  @override
  Future<bool> start({
    required String localeId,
    required void Function(String text) onResult,
    required void Function(String? error) onDone,
    void Function(double level)? onLevel,
  }) async {
    this.localeId = localeId;
    this.onResult = onResult;
    this.onDone = onDone;
    this.onLevel = onLevel;
    return listening = available;
  }

  @override
  Future<void> stop() async => listening = false;
}

Future<void> openPreview(
  WidgetTester tester, {
  Future<void> Function()? onPracticeCompleted,
  PhraseRecognizer? recognizer,
}) async {
  await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
    data: const MediaQueryData(disableAnimations: true),
    child: Scaffold(
        body: SingleChildScrollView(
            child: StagePreviewScreen(
                embedded: true,
                recognizer: recognizer ?? FakeRecognizer(),
                onPracticeCompleted: onPracticeCompleted))),
  )));
}

/// 말풍선 시간(3초)과 문장 사이 기본 간격(1.5초)이 지나 다음 문장으로 넘어가기까지 시간을 흘린다.
Future<void> finishPhrase(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 49; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> tapTooltip(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.byTooltip(label));
  await tester.tap(find.byTooltip(label));
  await tester.pump();
}

Finder currentPhrase(String phrase) => find.byWidgetPredicate((widget) =>
    widget is Semantics && widget.properties.label == '앵무새가 이야기해요. $phrase');
const complete = ValueKey('complete-repeat');
const microphone = ValueKey('preview-microphone');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('자동 반복은 XP를 주거나 응답 UI를 띄우지 않는다', (tester) async {
    await openPreview(tester);
    expect(currentPhrase('Hello there!'), findsOneWidget);
    await finishPhrase(tester);
    expect(currentPhrase('How was your day?'), findsOneWidget);
    expect(find.byKey(complete), findsNothing);
    expect(find.text('0 / 10 XP'), findsOneWidget);
    expect(
        (await SharedPreferences.getInstance())
            .getInt('parrokit.speaking.xp.v1.guest'),
        isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('따라 말하기는 문장과 음파만 표시하고 체크로 다음 문장으로 넘어간다', (tester) async {
    await openPreview(tester);
    await tapTooltip(tester, '따라 말하기 모드');
    await finishPhrase(tester);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byKey(microphone), findsOneWidget);
    expect(find.text('같은 문장 다시 보기'), findsNothing);
    expect(find.text('자동 모드로 돌아가기'), findsNothing);
    expect(find.text('따라 말해보세요'), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    expect(currentPhrase('Hello there!'), findsOneWidget);
    await tester.ensureVisible(find.byKey(microphone));
    await tester.tap(find.byKey(microphone));
    await tester.pump();
    expect(find.text('0 / 10 XP'), findsOneWidget);
    await tester.ensureVisible(find.byKey(complete));
    await tester.tap(find.byKey(complete));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(currentPhrase('How was your day?'), findsOneWidget);
    await tapTooltip(tester, '자동 모드');
    await finishPhrase(tester);
    expect(find.byKey(complete), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('일시 정지 중에는 응답 UI가 나타나지 않는다', (tester) async {
    await openPreview(tester);
    await tapTooltip(tester, '따라 말하기 모드');
    await tester.pump(const Duration(seconds: 1));
    await tapTooltip(tester, '말하기 일시 정지');
    await tester.pump(const Duration(seconds: 5));
    expect(find.byKey(complete), findsNothing);
    await tapTooltip(tester, '말하기 재개');
    await finishPhrase(tester);
    expect(find.byKey(complete), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('마이크 시안은 XP 없음, 체크 중복 지급 방지와 레벨 복원', (tester) async {
    SharedPreferences.setMockInitialValues(
        {'parrokit.speaking.xp.v1.guest': 9});
    await openPreview(tester);
    await tester.pump();
    await tapTooltip(tester, '따라 말하기 모드');
    await finishPhrase(tester);
    await tester.ensureVisible(find.byKey(microphone));
    await tester.tap(find.byKey(microphone));
    await tester.pump();
    expect(
        (await SharedPreferences.getInstance())
            .getInt('parrokit.speaking.xp.v1.guest'),
        9);
    final confirm = tester.widget<IconButton>(find.byKey(complete)).onPressed!;
    confirm();
    confirm();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
        (await SharedPreferences.getInstance())
            .getInt('parrokit.speaking.xp.v1.guest'),
        10);
    expect(find.text('Lv.2'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await openPreview(tester);
    await tester.pump();
    expect(find.text('Lv.2'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('따라 말하기 완료는 일일 기록 콜백을 한 번만 호출한다', (tester) async {
    var completionCount = 0;
    await openPreview(
      tester,
      onPracticeCompleted: () async => completionCount++,
    );
    await tapTooltip(tester, '따라 말하기 모드');
    await finishPhrase(tester);

    final confirm = tester.widget<IconButton>(find.byKey(complete)).onPressed!;
    confirm();
    confirm();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(completionCount, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('기본 문장의 앵무새 말하기와 사용자 연습 횟수를 기록한다', (tester) async {
    await openPreview(tester);
    await tapTooltip(tester, '따라 말하기 모드');
    await finishPhrase(tester);

    var activity = await SentenceActivityStore.load('guest', 'basic-en-001');
    expect(activity.parrotSpeakCount, 1);
    expect(activity.practiceCount, 0);

    await tester.tap(find.byKey(complete));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    activity = await SentenceActivityStore.load('guest', 'basic-en-001');
    expect(activity.practiceCount, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('문장 추가 화면에서 원문, 뜻, 발음을 저장해 바로 보여준다', (tester) async {
    await openPreview(tester);
    await tester.tap(find.byKey(const ValueKey('add-phrase')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('문장 추가'), findsOneWidget);
    expect(find.byKey(const ValueKey('sentence-language')), findsOneWidget);
    expect(find.text('발음 (선택)'), findsOneWidget);
    // 뜻이 없으면 저장할 수 없다.
    await tester.enterText(
        find.byKey(const ValueKey('sentence-text')), 'Nice to meet you!');
    await tester.pump();
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('save-sentence')))
            .onPressed,
        isNull);
    await tester.enterText(
        find.byKey(const ValueKey('sentence-translation')), '만나서 반가워요!');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('save-sentence')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(currentPhrase('Nice to meet you!'), findsOneWidget);
    final saved = (await MySentenceStore.loadFor('guest', '영어'))
        .firstWhere((s) => s.text == 'Nice to meet you!');
    expect(saved.translation, '만나서 반가워요!');
    expect(saved.pronunciation, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('인식된 말이 문장과 충분히 비슷하면 자동으로 완료한다', (tester) async {
    final recognizer = FakeRecognizer();
    await openPreview(tester, recognizer: recognizer);
    await tapTooltip(tester, '따라 말하기 모드');
    await finishPhrase(tester);
    await tester.ensureVisible(find.byKey(microphone));
    await tester.tap(find.byKey(microphone));
    await tester.pump();
    expect(recognizer.listening, isTrue);
    expect(recognizer.localeId, 'en_US');
    recognizer.onResult!('hello');
    await tester.pump();
    expect(currentPhrase('Hello there!'), findsOneWidget);
    recognizer.onResult!('hello there');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(recognizer.listening, isFalse);
    expect(currentPhrase('How was your day?'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('인식이 끝났는데 비슷하지 않으면 다시 말하도록 안내한다', (tester) async {
    final recognizer = FakeRecognizer();
    await openPreview(tester, recognizer: recognizer);
    await tapTooltip(tester, '따라 말하기 모드');
    await finishPhrase(tester);
    await tester.ensureVisible(find.byKey(microphone));
    await tester.tap(find.byKey(microphone));
    await tester.pump();
    recognizer.onResult!('good morning');
    recognizer.onDone!(null);
    await tester.pump();
    expect(find.text('다시 한번 말해볼까요?'), findsOneWidget);
    expect(currentPhrase('Hello there!'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('음성 인식을 쓸 수 없으면 안내하고 체크로 넘어갈 수 있다', (tester) async {
    final recognizer = FakeRecognizer()..available = false;
    await openPreview(tester, recognizer: recognizer);
    await tapTooltip(tester, '따라 말하기 모드');
    await finishPhrase(tester);
    await tester.ensureVisible(find.byKey(microphone));
    await tester.tap(find.byKey(microphone));
    await tester.pump();
    expect(find.textContaining('음성 인식을 쓸 수 없어요'), findsOneWidget);
    expect(find.byKey(complete), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('듣는 동안 목소리 크기에 맞춰 음파 막대 높이가 달라진다', (tester) async {
    final recognizer = FakeRecognizer();
    await openPreview(tester, recognizer: recognizer);
    await tapTooltip(tester, '따라 말하기 모드');
    await finishPhrase(tester);
    await tester.ensureVisible(find.byKey(microphone));
    await tester.tap(find.byKey(microphone));
    await tester.pump();
    double barHeight() =>
        tester.getSize(find.byKey(const ValueKey('wave-bar-0'))).height;
    recognizer.onLevel!(0.1);
    await tester.pump();
    final quiet = barHeight();
    expect(quiet, lessThan(10));
    for (var i = 0; i < 6; i++) {
      recognizer.onLevel!(1);
      await tester.pump();
    }
    expect(barHeight(), greaterThan(quiet));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('설정의 말하기 간격 슬라이더 값이 저장된다', (tester) async {
    await openPreview(tester);
    await tester.pump();
    await tapTooltip(tester, '설정');
    await tester.pump();
    expect(find.text('1.5초'), findsWidgets);
    final slider =
        tester.widget<Slider>(find.byKey(const ValueKey('gap-slider')));
    slider.onChanged!(7.5);
    await tester.pump();
    await tester.tap(find.text('저장'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
        (await SharedPreferences.getInstance())
            .getDouble('parrokit.speaking.gap_seconds.v1.guest'),
        7.5);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('인식 성공과 실패, 직접 완료가 모두 시도 기록으로 남는다', (tester) async {
    final recognizer = FakeRecognizer();
    await openPreview(tester, recognizer: recognizer);
    await tapTooltip(tester, '따라 말하기 모드');
    await finishPhrase(tester);

    // 1) 실패: 엉뚱한 말을 하고 인식이 끝난다.
    await tester.ensureVisible(find.byKey(microphone));
    await tester.tap(find.byKey(microphone));
    await tester.pump();
    recognizer.onResult!('good morning');
    await tester.pump(const Duration(milliseconds: 500));
    recognizer.onDone!(null);
    await tester.pump();

    // 2) 성공: 다시 눌러 제대로 말한다.
    await tester.tap(find.byKey(microphone));
    await tester.pump();
    recognizer.onResult!('hello there');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final log = await PracticeLogStore.load('guest');
    expect(log, hasLength(2));
    expect(log[0].success, isFalse);
    expect(log[0].heard, 'good morning');
    expect(log[0].durationMs, greaterThanOrEqualTo(0));
    expect(log[1].success, isTrue);
    expect(log[1].score, 1);
    expect(log[1].sentenceId, 'basic-en-001');
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('체크 버튼으로 직접 완료하면 직접 완료로 기록한다', (tester) async {
    await openPreview(tester);
    await tapTooltip(tester, '따라 말하기 모드');
    await finishPhrase(tester);
    await tester.ensureVisible(find.byKey(complete));
    await tester.tap(find.byKey(complete));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final log = await PracticeLogStore.load('guest');
    expect(log, hasLength(1));
    expect(log.single.manual, isTrue);
    expect(log.single.success, isTrue);
    expect(log.single.score, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('설정에서 들은 횟수 기록을 끄면 저장된다', (tester) async {
    await openPreview(tester);
    await tester.pump();
    await tapTooltip(tester, '설정');
    await tester.pump();
    final toggle = find.byKey(const ValueKey('count-listen-switch'));
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    await tester.tap(toggle);
    await tester.pump();
    await tester.tap(find.text('저장'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
        (await SharedPreferences.getInstance())
            .getBool('parrokit.speaking.count_listen.v1.guest'),
        isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
