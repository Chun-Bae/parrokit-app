import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/my_sentence_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parrokit/core/content/practice_log.dart';
import 'package:parrokit/core/content/sentence_activity_store.dart';
import 'package:parrokit/core/speech/phrase_recognizer.dart';
import 'package:parrokit/core/speech/presentation/speech_practice_view.dart';
import 'package:parrokit/features/home/dashboard/presentation/stage_preview_screen.dart';

class FakeRecognizer implements PhraseRecognizer {
  bool available = true;
  bool listening = false;

  /// 몇 번 듣기 시작했는지. 자동으로 다시 듣는지 보는 데 쓴다.
  int starts = 0;
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
    if (available) starts++;
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
  // 기본 문장을 없앤 뒤로는 무대가 내 문장을 읽어 와야 글이 나온다(5차).
  await tester.pump();
  await tester.pump();
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
const restart = ValueKey('restart-practice');

/// 기본으로 주던 예시 문장을 없앴으므로(5차), 무대 테스트는 내 문장을
/// 몇 개 넣어 두고 시작한다. 순서는 저장한 차례 그대로다.
const _testSentences = [
  ('Hello there!', '안녕하세요!'),
  ('How was your day?', '오늘 하루 어땠어요?'),
  ('Can I get a coffee?', '커피 한 잔 주시겠어요?'),
];

String sentenceId(String text) => MySentenceStore.idFor('영어', text);

void main() {
  setUp(() async {
    // 자동으로 듣기는 아래 '자동으로 듣기' 묶음에서 따로 본다. 나머지 테스트는
    // 마이크를 눌러서 하는 흐름이라 꺼 둔다(5차).
    SharedPreferences.setMockInitialValues(
        {'parrokit.speaking.auto_listen.v1.guest': false});
    MySentenceStore.cloud = null;
    for (final (text, translation) in _testSentences) {
      await MySentenceStore.add('guest',
          language: '영어', text: text, translation: translation);
    }
  });
  testWidgets('왼쪽 버튼에도 이름이 보인다', (tester) async {
    // 아래 조작 줄은 글자가 있는데 왼쪽 버튼만 아이콘뿐이라, 눌러 보기 전에는
    // 무엇인지 알 수 없었다(5차).
    await openPreview(tester);
    for (final name in ['소리', '문장 추가', '문장 설정', '말하기 설정']) {
      expect(find.text(name), findsWidgets, reason: name);
    }
  });

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
    await tapTooltip(tester, '따라 말하기 모드 켜기');
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
    await tapTooltip(tester, '따라 말하기 모드 끄기');
    await finishPhrase(tester);
    expect(find.byKey(complete), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('일시 정지 중에는 응답 UI를 쓸 수 없다', (tester) async {
    await openPreview(tester);
    await tapTooltip(tester, '따라 말하기 모드 켜기');
    await tester.pump(const Duration(seconds: 1));
    await tapTooltip(tester, '말하기 일시 정지');
    await tester.pump(const Duration(seconds: 5));
    expect(tester.widget<IconButton>(find.byKey(complete)).onPressed, isNull);
    await tapTooltip(tester, '말하기 재개');
    await finishPhrase(tester);
    expect(
        tester.widget<IconButton>(find.byKey(complete)).onPressed, isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('앵무새가 말하는 중에도 마이크를 누르면 멈추고 내 차례가 된다', (tester) async {
    final recognizer = FakeRecognizer();
    await openPreview(tester, recognizer: recognizer);
    await tapTooltip(tester, '따라 말하기 모드 켜기');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(microphone), findsOneWidget);
    await tester.ensureVisible(find.byKey(microphone));
    await tester.tap(find.byKey(microphone));
    await tester.pump();
    expect(recognizer.listening, isTrue);
    await tester.pump(const Duration(seconds: 5));
    expect(currentPhrase('Hello there!'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('마이크 시안은 XP 없음, 체크 중복 지급 방지와 레벨 복원', (tester) async {
    SharedPreferences.setMockInitialValues({
      'parrokit.speaking.xp.v1.guest': 9.95,
      'parrokit.speaking.auto_listen.v1.guest': false,
    });
    await openPreview(tester);
    await tester.pump();
    await tapTooltip(tester, '따라 말하기 모드 켜기');
    await finishPhrase(tester);
    await tester.ensureVisible(find.byKey(microphone));
    await tester.tap(find.byKey(microphone));
    await tester.pump();
    expect(
        (await SharedPreferences.getInstance())
            .getDouble('parrokit.speaking.xp.v1.guest'),
        9.95);
    final confirm = tester.widget<IconButton>(find.byKey(complete)).onPressed!;
    confirm();
    confirm();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
        (await SharedPreferences.getInstance())
            .getDouble('parrokit.speaking.xp.v1.guest'),
        10.05);
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
    await tapTooltip(tester, '따라 말하기 모드 켜기');
    await finishPhrase(tester);

    final confirm = tester.widget<IconButton>(find.byKey(complete)).onPressed!;
    confirm();
    confirm();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(completionCount, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('내 문장의 앵무새 말하기와 사용자 연습 횟수를 기록한다', (tester) async {
    await openPreview(tester);
    await tapTooltip(tester, '따라 말하기 모드 켜기');
    await finishPhrase(tester);

    var activity =
        await SentenceActivityStore.load('guest', sentenceId('Hello there!'));
    expect(activity.parrotSpeakCount, 1);
    expect(activity.practiceCount, 0);

    await tester.tap(find.byKey(complete));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    activity =
        await SentenceActivityStore.load('guest', sentenceId('Hello there!'));
    expect(activity.practiceCount, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('문장 설정의 주황 점은 처음 한 번 열면 사라지고 다시 켜지지 않는다',
      (tester) async {
    Finder badge() => find.descendant(
        of: find.byKey(const ValueKey('phrase-settings')),
        matching: find.byKey(const ValueKey('menu-badge')));
    await openPreview(tester);
    await tester.pump(); // 저장값 읽기(loadXp)가 끝나길 기다린다.
    await tester.pump();
    expect(badge(), findsOneWidget);
    await tapTooltip(tester, '문장 설정');
    await tester.pump(const Duration(milliseconds: 400));
    await tapTooltip(tester, '닫기');
    await tester.pump(const Duration(milliseconds: 400));
    expect(badge(), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('parrokit.home.phrase_settings_seen.v1'), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('문장 설정 창의 +는 창을 닫고 문장 추가 화면을 연다', (tester) async {
    await openPreview(tester);
    await tapTooltip(tester, '문장 설정');
    await tester.pump(const Duration(milliseconds: 400));
    final add = find.byKey(const ValueKey('phrase-settings-add'));
    expect(add, findsOneWidget);
    await tester.tap(add);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(add, findsNothing);
    expect(find.byKey(const ValueKey('sentence-language')), findsOneWidget);
  });

  testWidgets('문장 설정 창의 체크는 적용 없이 바로 저장되고 무대에 반영된다', (tester) async {
    final targetId = sentenceId('How was your day?');
    await openPreview(tester);
    expect(currentPhrase('Hello there!'), findsOneWidget);
    await tapTooltip(tester, '문장 설정');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('적용'), findsNothing);
    final tile = find.widgetWithText(CheckboxListTile, 'How was your day?');
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pump();
    // 창을 닫기 전에 이미 저장돼 있다(문장 탭 '앵무새 끄기'와 같은 값).
    expect((await SentenceActivityStore.load('guest', targetId)).routineEnabled,
        isFalse);
    await tapTooltip(tester, '닫기');
    await tester.pump(const Duration(milliseconds: 400));
    // 꺼진 문장은 건너뛰고 다음 문장으로 간다.
    await finishPhrase(tester);
    expect(currentPhrase('How was your day?'), findsNothing);
    expect(currentPhrase('Can I get a coffee?'), findsOneWidget);
  });

  testWidgets('문장 추가 화면에서 원문, 뜻, 발음을 저장해 바로 보여준다', (tester) async {
    await openPreview(tester);
    await tester.tap(find.byKey(const ValueKey('add-phrase')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // 왼쪽 버튼에도 '문장 추가' 글자가 생겨(5차) 화면에 둘이 보인다.
    // 창이 열렸는지는 아래 칸들로 확인한다.
    expect(find.text('문장 추가'), findsWidgets);
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
    await tapTooltip(tester, '따라 말하기 모드 켜기');
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
    expect(find.text('100점'), findsOneWidget);
    expect(recognizer.listening, isFalse);
    // 통과해도 자동으로 넘어가지 않고 체크를 눌러야 넘어간다.
    await tester.pump(const Duration(seconds: 3));
    expect(currentPhrase('Hello there!'), findsOneWidget);
    await tester.tap(find.byKey(complete));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(currentPhrase('How was your day?'), findsOneWidget);
    expect(
        (await SharedPreferences.getInstance())
            .getDouble('parrokit.speaking.xp.v1.guest'),
        1.0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('인식이 끝났는데 비슷하지 않으면 다시 말하도록 안내한다', (tester) async {
    final recognizer = FakeRecognizer();
    await openPreview(tester, recognizer: recognizer);
    await tapTooltip(tester, '따라 말하기 모드 켜기');
    await finishPhrase(tester);
    await tester.ensureVisible(find.byKey(microphone));
    await tester.tap(find.byKey(microphone));
    await tester.pump();
    recognizer.onResult!('good morning');
    recognizer.onDone!(null);
    await tester.pump();
    expect(find.text('다시 한번 말해볼까요?'), findsOneWidget);
    expect(currentPhrase('Hello there!'), findsOneWidget);
    // 어디가 틀렸는지 보이게 내가 말한 것을 그대로 적는다(5차).
    expect(find.text('내가 말한 것'), findsOneWidget);
    expect(find.byKey(const ValueKey('speech-heard')), findsOneWidget);
    expect(find.text('good morning'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('음성 인식을 쓸 수 없으면 안내하고 체크로 넘어갈 수 있다', (tester) async {
    final recognizer = FakeRecognizer()..available = false;
    await openPreview(tester, recognizer: recognizer);
    await tapTooltip(tester, '따라 말하기 모드 켜기');
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
    await tapTooltip(tester, '따라 말하기 모드 켜기');
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
    await tapTooltip(tester, '말하기 설정');
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
    await tapTooltip(tester, '따라 말하기 모드 켜기');
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
    expect(log[1].sentenceId, sentenceId('Hello there!'));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('체크 버튼으로 직접 완료하면 직접 완료로 기록한다', (tester) async {
    await openPreview(tester);
    await tapTooltip(tester, '따라 말하기 모드 켜기');
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
  testWidgets('레벨 옆 도움말에 XP와 레벨 설명이 있다', (tester) async {
    await openPreview(tester);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('home-help')));
    await tester.pump();
    expect(find.text('XP와 레벨'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('말하기 설정에서 듣기 횟수 기록을 끄면 저장된다', (tester) async {
    await openPreview(tester);
    await tester.pump();
    await tapTooltip(tester, '말하기 설정');
    await tester.pump();
    // 창 제목이 버튼 이름과 같다(예전 '설정').
    expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('말하기 설정')),
        findsOneWidget);
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
  testWidgets('재생 순서 버튼은 누를 때마다 순서대로, 하나 반복, 랜덤으로 바뀐다', (tester) async {
    await openPreview(tester);
    expect(find.byTooltip('재생 순서: 순서대로'), findsOneWidget);
    await tapTooltip(tester, '재생 순서: 순서대로');
    expect(find.byTooltip('재생 순서: 하나 반복'), findsOneWidget);
    await tapTooltip(tester, '재생 순서: 하나 반복');
    expect(find.byTooltip('재생 순서: 랜덤'), findsOneWidget);
    await tapTooltip(tester, '재생 순서: 랜덤');
    expect(find.byTooltip('재생 순서: 순서대로'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('하나 반복은 같은 문장을 계속 보여준다', (tester) async {
    await openPreview(tester);
    await tapTooltip(tester, '재생 순서: 순서대로');
    await finishPhrase(tester);
    await finishPhrase(tester);
    expect(currentPhrase('Hello there!'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('랜덤은 방금 본 문장을 바로 다시 고르지 않는다', (tester) async {
    await openPreview(tester);
    await tapTooltip(tester, '재생 순서: 순서대로');
    await tapTooltip(tester, '재생 순서: 하나 반복');
    await finishPhrase(tester);
    expect(currentPhrase('Hello there!'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('다음 문장과 이전 문장 버튼으로 바로 넘어간다', (tester) async {
    await openPreview(tester);
    await tester.pump();
    expect(currentPhrase('Hello there!'), findsOneWidget);
    await tapTooltip(tester, '다음 문장');
    await tester.pump();
    expect(currentPhrase('How was your day?'), findsOneWidget);
    await tapTooltip(tester, '이전 문장');
    await tester.pump();
    expect(currentPhrase('Hello there!'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('하나 반복 중에도 다음 문장 버튼은 다음 문장으로 간다', (tester) async {
    await openPreview(tester);
    await tapTooltip(tester, '재생 순서: 순서대로');
    await tapTooltip(tester, '다음 문장');
    await tester.pump();
    expect(currentPhrase('Hello there!'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('따라 말하기 중에는 그 문장의 친밀도 게이지가 보이고 완료하면 올라간다', (tester) async {
    await openPreview(tester);
    expect(find.byKey(const ValueKey('repeat-affinity')), findsNothing);
    await tapTooltip(tester, '따라 말하기 모드 켜기');
    await tester.pump();
    expect(find.byKey(const ValueKey('repeat-affinity')), findsOneWidget);
    expect(find.text('Lv.1 낯선'), findsOneWidget);
    expect(find.text('다음 단계까지 3점'), findsOneWidget);
    await tester.ensureVisible(find.byKey(complete));
    await tester.tap(find.byKey(complete));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byTooltip('이전 문장'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // 점수 없이 체크로 넘기면 1점만 오른다(5차: 점수에 비례해 오른다).
    expect(find.text('다음 단계까지 2점'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('말풍선을 누르면 문장 정보 시트가 열린다', (tester) async {
    await openPreview(tester);
    await tester.pump();
    final box = find.byKey(const ValueKey('phrase-bubble'));
    final top = tester.getTopLeft(box);
    final size = tester.getSize(box);
    await tester.tapAt(Offset(top.dx + size.width / 2, top.dy + 30));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sentence-affinity')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('문장 목록에서 고른 문장으로 바로 이동한다', (tester) async {
    await openPreview(tester);
    await tester.pump();
    await tapTooltip(tester, '문장 목록');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('phrase-list')), findsOneWidget);
    // 문장 친밀도는 단계 이름과 함께(내 레벨과 헷갈리지 않게).
    expect(find.textContaining('Lv.1 낯선'), findsWidgets);
    await tester.tap(find.text('How was your day?'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('phrase-list')), findsNothing);
    expect(currentPhrase('How was your day?'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('무대는 글자 달린 조작 줄을 쓰고 준비 중 버튼은 없다', (tester) async {
    await openPreview(tester);
    await tester.pump();
    // 아이콘 아래 글자가 보인다.
    for (final label in ['따라 말하기', '듣기', '이전', '멈춤', '다음', '목록']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    // 눌러도 아무 일 없던 준비 중 버튼은 없다.
    for (final label in ['캐릭터 정보', '꾸미기', '도전 과제', '쇼츠 학습', '공유 영상', '학습 기록']) {
      expect(find.byTooltip(label), findsNothing, reason: label);
    }
    // 멈춤을 누르면 재생으로 바뀐다.
    await tester.tap(find.text('멈춤'));
    await tester.pump();
    expect(find.text('재생'), findsOneWidget);
    // 말하기 설정은 왼쪽 줄로 옮겼다.
    expect(find.byTooltip('말하기 설정'), findsOneWidget);
  });

  testWidgets('문장이 하나도 없으면 안내를 보여 주고 눌러서 추가할 수 있다', (tester) async {
    // 기본으로 주던 예시 문장을 없앴으므로(5차) 처음 켠 사람이 보는 화면이다.
    SharedPreferences.setMockInitialValues({});
    for (final sentence in await MySentenceStore.load('guest')) {
      await MySentenceStore.remove('guest', sentence.id);
    }
    await openPreview(tester);
    expect(currentPhrase('여기를 눌러 따라 말할 문장을 추가해 보세요.'), findsOneWidget);

    final bubble = tester.getRect(find.byKey(const ValueKey('phrase-bubble')));
    await tester.tapAt(Offset(bubble.center.dx, bubble.top + 40));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // 문장 정보 시트가 아니라 문장 추가 화면이 열린다.
    expect(find.byKey(const ValueKey('sentence-language')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  group('자동으로 듣기', () {
    setUp(() {
      // 기본값(켬)으로 돌려놓는다.
      SharedPreferences.setMockInitialValues({});
    });

    Future<FakeRecognizer> openWaiting(WidgetTester tester) async {
      final recognizer = FakeRecognizer();
      await openPreview(tester, recognizer: recognizer);
      await tapTooltip(tester, '따라 말하기 모드 켜기');
      await finishPhrase(tester);
      // 내 차례가 된 뒤 스스로 켜지기까지 기다린다.
      await tester.pump(const Duration(milliseconds: 600));
      return recognizer;
    }

    testWidgets('내 차례가 되면 마이크를 누르지 않아도 듣는다', (tester) async {
      final recognizer = await openWaiting(tester);

      expect(recognizer.listening, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('잘 따라 하면 누르지 않아도 다음 문장으로 넘어간다', (tester) async {
      var completed = 0;
      final recognizer = FakeRecognizer();
      await openPreview(tester,
          recognizer: recognizer,
          onPracticeCompleted: () async => completed++);
      await tapTooltip(tester, '따라 말하기 모드 켜기');
      await finishPhrase(tester);
      await tester.pump(const Duration(milliseconds: 600));
      expect(recognizer.starts, 1);

      // 지금 따라 말할 문장을 그대로 말했다고 친다.
      final view =
          tester.widget<SpeechPracticeView>(find.byType(SpeechPracticeView));
      recognizer.onResult!(view.phrase);
      await tester.pump();
      // 다 맞췄으므로 바로 끝내고, 잠깐 보여 준 뒤에 넘어간다.
      expect(find.text('잘했어요! 다음 문장으로 넘어가요.'), findsOneWidget);
      expect(completed, 0);

      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(completed, 1, reason: '체크를 누르지 않아도 넘어간다');
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('못 맞춘 채 끝나면 혼자 다시 듣는다', (tester) async {
      final recognizer = await openWaiting(tester);

      expect(recognizer.starts, 1);
      recognizer.onResult!('good morning');
      recognizer.onDone!(null);
      await tester.pump();
      expect(find.text('다시 한번 말해볼까요?'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1000));
      expect(recognizer.starts, 2, reason: '혼자 다시 들어야 한다');
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('정해진 횟수를 넘기면 그만 듣고 기다린다', (tester) async {
      final recognizer = await openWaiting(tester);

      for (var i = 0; i < 4; i++) {
        recognizer.onDone!(null);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1000));
      }

      expect(recognizer.starts, 3, reason: '처음 한 번과 다시 듣기 두 번까지만');
      expect(find.text('다시 하기를 누르면 또 들을게요. 체크를 누르면 다음 문장으로 넘어가요.'),
          findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('자동일 때는 마이크 버튼 대신 다시 하기 버튼이 있다', (tester) async {
      await openWaiting(tester);

      expect(find.byKey(microphone), findsNothing);
      expect(find.byKey(restart), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('다시 하기를 누르면 들은 것을 버리고 처음부터 다시 듣는다', (tester) async {
      final recognizer = await openWaiting(tester);
      recognizer.onResult!('good');
      await tester.pump();
      expect(find.byKey(const ValueKey('speech-heard')), findsOneWidget);

      await tester.ensureVisible(find.byKey(restart));
      await tester.tap(find.byKey(restart));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey('speech-heard')), findsNothing);
      expect(find.byKey(const ValueKey('speech-score')), findsNothing);
      expect(recognizer.starts, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('그만 듣고 기다리는 중에도 다시 하기로 또 들을 수 있다', (tester) async {
      final recognizer = await openWaiting(tester);
      for (var i = 0; i < 4; i++) {
        recognizer.onDone!(null);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1000));
      }
      expect(recognizer.starts, 3);

      await tester.ensureVisible(find.byKey(restart));
      await tester.tap(find.byKey(restart));
      await tester.pump();
      await tester.pump();
      expect(recognizer.starts, 4, reason: '기다리는 중에도 다시 들을 수 있다');
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('말하기 설정에서 끄면 저장되고 스스로 듣지 않는다', (tester) async {
      final recognizer = FakeRecognizer();
      await openPreview(tester, recognizer: recognizer);
      await tapTooltip(tester, '말하기 설정');
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byKey(const ValueKey('auto-listen-switch')));
      await tester.pump();
      await tester.tap(find.text('저장'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
          (await SharedPreferences.getInstance())
              .getBool('parrokit.speaking.auto_listen.v1.guest'),
          isFalse);

      await tapTooltip(tester, '따라 말하기 모드 켜기');
      await finishPhrase(tester);
      await tester.pump(const Duration(milliseconds: 600));
      expect(recognizer.listening, isFalse);
      expect(find.byKey(microphone), findsOneWidget, reason: '끄면 마이크로 돌아간다');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  test('문장 설정 창은 무엇의 수인지 적는다', () {
    // 숫자만 '50 / 50'이라 무엇을 세는지 알 수 없었다(5차 UX 점검).
    expect(routineCountLabel(on: 3, total: 5), '켠 문장 3 / 5');
    expect(routineCountLabel(on: 5, total: 5), '5개 모두 켜짐');
    expect(routineCountLabel(on: 0, total: 0), '켠 문장 0 / 0');
  });
}
