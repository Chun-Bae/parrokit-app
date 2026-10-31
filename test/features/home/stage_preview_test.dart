import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/my_sentence_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parrokit/core/content/sentence_activity_store.dart';
import 'package:parrokit/features/home/dashboard/presentation/stage_preview_screen.dart';

Future<void> openPreview(
  WidgetTester tester, {
  Future<void> Function()? onPracticeCompleted,
}) async {
  await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
    data: const MediaQueryData(disableAnimations: true),
    child: Scaffold(
        body: SingleChildScrollView(
            child: StagePreviewScreen(
                embedded: true, onPracticeCompleted: onPracticeCompleted))),
  )));
}

Future<void> finishPhrase(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 3));
  await tester.pump();
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

  testWidgets('문장 추가 입력창은 닫힌 뒤에도 안전하게 문장을 반영한다', (tester) async {
    await openPreview(tester);
    await tester.tap(find.byKey(const ValueKey('add-phrase')));
    await tester.pump();
    expect(find.text('문장 추가'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Nice to meet you!');
    await tester.tap(find.widgetWithText(FilledButton, '추가'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(currentPhrase('Nice to meet you!'), findsOneWidget);
    expect(
        (await MySentenceStore.loadFor('guest', '영어')).map((s) => s.text),
        contains('Nice to meet you!'));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
