import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/features/settings/subscription/presentation/providers/subscription_provider.dart';
import 'package:parrokit/core/content/sentence_assist.dart';
import 'package:parrokit/features/home/dashboard/presentation/add_sentence_screen.dart';

Future<void> open(WidgetTester tester, String language) =>
    tester.pumpWidget(withSubscription(AddSentenceScreen(language: language)));

/// 한도를 다 쓴 화면이 구독 단계를 읽으므로 테스트에도 Provider를 둔다.
Widget withSubscription(Widget child, {SubscriptionProvider? provider}) =>
    ChangeNotifierProvider<SubscriptionProvider>.value(
        value: provider ?? SubscriptionProvider(firestore: FakeFirebaseFirestore()),
        child: MaterialApp(home: child));

/// 서버가 알려 준 하루 한도와 남은 횟수를 흉내 낸다.
class _UsageAssist implements SentenceAssist {
  _UsageAssist({required this.dailyLimit, required this.remainingToday});

  @override
  int? dailyLimit;
  @override
  int? remainingToday;
  @override
  int? examplesRemainingToday;
  @override
  int? exampleDailyLimit;
  @override
  int? maxExamplesPerWord;

  @override
  int? exampleCredits;

  @override
  int? assistCredits;

  @override
  Future<void> refreshUsage() async {}

  @override
  Future<SentenceSuggestion> suggest(
          {required String language, required String text}) async =>
      const SentenceSuggestion(translation: '안녕');

  @override
  Future<SentenceComplete> complete({
    required String language,
    String text = '',
    String translation = '',
    String pronunciation = '',
    bool word = false,
  }) async =>
      const SentenceComplete();

  @override
  Future<WordSuggestion> suggestWord({
    required String language,
    required String word,
    List<String> existingExamples = const [],
    int count = 1,
  }) async =>
      const WordSuggestion();
}


/// 횟수 조회가 늦게 끝나는 도우미. 다 읽기 전까지는 한도를 모른다.
class _SlowUsageAssist extends _UsageAssist {
  _SlowUsageAssist() : super(dailyLimit: null, remainingToday: null);

  final done = Completer<void>();

  @override
  Future<void> refreshUsage() async {
    await done.future;
    dailyLimit = 3;
    remainingToday = 3;
  }
}

/// 빈 칸을 채워 주는 도우미(5차 545).
class _CompleteAssist extends _UsageAssist {
  _CompleteAssist() : super(dailyLimit: 3, remainingToday: 3);

  final calls = <List<String>>[];

  @override
  Future<SentenceComplete> complete({
    required String language,
    String text = '',
    String translation = '',
    String pronunciation = '',
    bool word = false,
  }) async {
    calls.add([text, translation, pronunciation]);
    return const SentenceComplete(
        text: 'こんにちは', translation: '안녕하세요', pronunciation: '곤니치와');
  }
}

void main() {
  testWidgets('한글 소리 전용 칸은 없다', (tester) async {
    // 발음칸이 같은 일을 하므로 걷어냈다(5차 541, 사용자 요청).
    await open(tester, '일본어');
    expect(find.byKey(const ValueKey('sentence-hangul')), findsNothing);
    expect(find.byKey(const ValueKey('auto-fill-now')), findsOneWidget);
  });

  testWidgets('발음만 적고 눌러도 준비 중이면 안내한다', (tester) async {
    await open(tester, '일본어');
    await tester.enterText(
        find.byKey(const ValueKey('sentence-pronunciation')), '곤니치와');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('auto-fill-now')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('auto-fill-message')), findsOneWidget);
    expect(find.textContaining('쓸 수 없어요'), findsWidgets);
  });

  testWidgets('채우기 버튼은 하나라도 적어야 켜지고, 연결 전이면 안내하고 직접 입력할 수 있다',
      (tester) async {
    await open(tester, '영어');
    FilledButton fill() => tester
        .widget<FilledButton>(find.byKey(const ValueKey('auto-fill-now')));
    expect(fill().onPressed, isNull);
    // 횟수를 못 읽었어도 아무것도 안 보이지 않고 안내를 보여준다.
    await tester.pump();
    expect(find.byKey(const ValueKey('usage-count')), findsNothing);
    expect(find.byKey(const ValueKey('usage-unknown')), findsOneWidget);
    expect(find.textContaining('다시 확인'), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey('sentence-text')), 'Hello');
    await tester.pump();
    expect(fill().onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('auto-fill-now')));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('채우기를 쓸 수 없어요'), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey('sentence-translation')), '안녕');
    await tester.pump();
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('save-sentence')))
            .onPressed,
        isNotNull);
  });

  testWidgets('입력하면 자동으로 채우기 스위치는 없다', (tester) async {
    await open(tester, '영어');
    expect(find.byKey(const ValueKey('auto-fill-switch')), findsNothing);
    expect(find.textContaining('자동으로 채우기'), findsNothing);
  });



  testWidgets('서버가 알려 준 횟수를 버튼 옆에 "쓴 횟수 / 한도"로 보여준다', (tester) async {
    await tester.pumpWidget(withSubscription(AddSentenceScreen(
        language: '영어',
        assist: _UsageAssist(dailyLimit: 3, remainingToday: 2))));
    await tester.pump();
    expect(find.byKey(const ValueKey('usage-count')), findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('usage-count')),
            matching: find.text('1/3')),
        findsOneWidget);
    expect(find.textContaining('남았어요'), findsNothing);
  });

  testWidgets('횟수를 모두 쓰면 3 / 3이 되고 채우기 버튼이 꺼진다', (tester) async {
    await tester.pumpWidget(withSubscription(AddSentenceScreen(
        language: '영어',
        assist: _UsageAssist(dailyLimit: 3, remainingToday: 0))));
    await tester.pump();
    await tester.enterText(
        find.byKey(const ValueKey('sentence-text')), 'Hello');
    await tester.pump();
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('usage-count')),
            matching: find.text('3/3')),
        findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('auto-fill-now')))
            .onPressed,
        isNull);
  });

  testWidgets('원문을 적고 뒤로 가면 버릴지 묻고, 비어 있으면 바로 닫힌다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => const AddSentenceScreen(language: '영어'))),
          child: const Text('열기'),
        ),
      ),
    ));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('쓰던 내용을 버릴까요?'), findsNothing);
    expect(find.text('열기'), findsOneWidget);

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('sentence-text')), 'Hello');
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('쓰던 내용을 버릴까요?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('draft-discard')));
    await tester.pumpAndSettle();
    expect(find.text('열기'), findsOneWidget);
  });

  testWidgets('무료 사용자가 횟수를 다 쓰면 구독 길을 한 줄로 알린다', (tester) async {
    await tester.pumpWidget(withSubscription(AddSentenceScreen(
        language: '영어',
        assist: _UsageAssist(dailyLimit: 3, remainingToday: 0))));
    await tester.pump();

    expect(find.byKey(const ValueKey('assist-quota-upsell')), findsOneWidget);
    expect(find.text('구독하면 하루에 더 많이 채울 수 있어요.'), findsOneWidget);
    expect(find.text('구독 보기'), findsOneWidget);
  });

  testWidgets('아직 남아 있으면 구독 안내를 보여 주지 않는다', (tester) async {
    await tester.pumpWidget(withSubscription(AddSentenceScreen(
        language: '영어',
        assist: _UsageAssist(dailyLimit: 3, remainingToday: 1))));
    await tester.pump();

    expect(find.byKey(const ValueKey('assist-quota-upsell')), findsNothing);
  });

  testWidgets('구독 중인 사람에게는 다 썼어도 구독 안내를 보여 주지 않는다', (tester) async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('uid-1').set({
      'subscription': {'tier': 'pro', 'status': 'active'},
    });
    final provider = SubscriptionProvider(firestore: db);
    addTearDown(provider.dispose);
    provider.syncUser('uid-1');
    // 테스트 시계는 멈춰 있어서, 서버 문서가 도착하게 실제 시간을 잠깐 흘린다.
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));

    await tester.pumpWidget(withSubscription(
        AddSentenceScreen(
            language: '영어',
            assist: _UsageAssist(dailyLimit: 60, remainingToday: 0)),
        provider: provider));
    await tester.pump();

    expect(find.byKey(const ValueKey('assist-quota-upsell')), findsNothing);
  });

  // 횟수를 읽는 동안 누르면, 이미 다 쓴 사람도 서버에 한 번 부딪히고 나서야
  // 안다. 단어 시트와 같게 읽는 동안은 막는다(5차 516).
  testWidgets('횟수를 읽는 동안에는 채우기도 변환도 눌리지 않는다', (tester) async {
    final assist = _SlowUsageAssist();
    await tester.pumpWidget(withSubscription(
        AddSentenceScreen(language: '일본어', assist: assist)));
    await tester.enterText(
        find.byKey(const ValueKey('sentence-pronunciation')), '곤니치와');
    await tester.pump();

    FilledButton fill() => tester
        .widget<FilledButton>(find.byKey(const ValueKey('auto-fill-now')));
    expect(find.byKey(const ValueKey('usage-loading')), findsOneWidget);
    expect(fill().onPressed, isNull, reason: '횟수를 읽는 중이다');

    assist.done.complete();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('usage-count')), findsOneWidget);
    expect(fill().onPressed, isNotNull);
  });

  // 서버가 쉬다 깨는 첫 조회는 15초를 넘긴다. 그동안 단추가 회색으로
  // 죽어만 있어 고장으로 보였다(5차 539, 사용자 지적).
  testWidgets('횟수를 읽는 동안 채우기 단추가 돌아간다', (tester) async {
    final assist = _SlowUsageAssist();
    await tester.pumpWidget(withSubscription(
        AddSentenceScreen(language: '일본어', assist: assist)));
    await tester.pump();
    await tester.enterText(
        find.byKey(const ValueKey('sentence-pronunciation')), '곤니치와');
    await tester.pump();

    final button = find.byKey(const ValueKey('auto-fill-now'));
    expect(button, findsOneWidget);
    expect(
      find.descendant(
          of: button, matching: find.byType(CircularProgressIndicator)),
      findsOneWidget,
      reason: '기다리는 중이라는 표시가 없으면 고장으로 읽힌다',
    );
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    assist.done.complete();
    await tester.pumpAndSettle();
    expect(
      find.descendant(
          of: button, matching: find.byType(CircularProgressIndicator)),
      findsNothing,
    );
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
  });

  // 단추 하나가 셋을 다 한다(5차 545, 사용자 요청).
  group('빈 칸 채우기', () {
    const button = ValueKey('auto-fill-now');

    testWidgets('뜻만 적고 눌러도 원문과 발음까지 한 번에 찬다', (tester) async {
      final assist = _CompleteAssist();
      await tester.pumpWidget(withSubscription(
          AddSentenceScreen(language: '일본어', assist: assist)));
      await tester.pump();

      expect(tester.widget<FilledButton>(find.byKey(button)).onPressed, isNull,
          reason: '아무것도 안 적으면 채울 재료가 없다');

      await tester.enterText(
          find.byKey(const ValueKey('sentence-translation')), '안녕하세요');
      await tester.pump();
      expect(
          tester.widget<FilledButton>(find.byKey(button)).onPressed, isNotNull);

      await tester.tap(find.byKey(button));
      await tester.pump();
      await tester.pump();

      expect(assist.calls, [
        ['', '안녕하세요', '']
      ], reason: '한 번만 부른다');
      String read(String key) => tester
          .widget<TextField>(find.byKey(ValueKey(key)))
          .controller!
          .text;
      expect(read('sentence-text'), 'こんにちは');
      expect(read('sentence-pronunciation'), '곤니치와');
      expect(read('sentence-translation'), '안녕하세요');
    });

    testWidgets('발음만 적어도 누를 수 있다', (tester) async {
      await tester.pumpWidget(withSubscription(
          AddSentenceScreen(language: '영어', assist: _CompleteAssist())));
      await tester.pump();

      await tester.enterText(
          find.byKey(const ValueKey('sentence-pronunciation')), '헬로 데어');
      await tester.pump();

      expect(
          tester.widget<FilledButton>(find.byKey(button)).onPressed, isNotNull);
    });

    testWidgets('손으로 둘을 적으면 꺼지고 까닭을 적는다', (tester) async {
      // 둘이 어긋나면 나머지 칸을 어느 쪽에 맞출지 알 수 없다(5차 553).
      await tester.pumpWidget(withSubscription(
          AddSentenceScreen(language: '일본어', assist: _CompleteAssist())));
      await tester.pump();

      await tester.enterText(
          find.byKey(const ValueKey('sentence-translation')), '안녕하세요');
      await tester.pump();
      expect(tester.widget<FilledButton>(find.byKey(button)).onPressed,
          isNotNull,
          reason: '하나만 있을 때는 켜져야 한다');

      await tester.enterText(
          find.byKey(const ValueKey('sentence-pronunciation')), '아리가또');
      await tester.pump();

      expect(tester.widget<FilledButton>(find.byKey(button)).onPressed, isNull);
      expect(find.textContaining('한 칸만 적어'), findsOneWidget);
    });

    testWidgets('원문과 뜻을 손으로 적어도 꺼진다', (tester) async {
      await tester.pumpWidget(withSubscription(
          AddSentenceScreen(language: '일본어', assist: _CompleteAssist())));
      await tester.pump();

      await tester.enterText(
          find.byKey(const ValueKey('sentence-text')), 'こんにちは');
      await tester.enterText(
          find.byKey(const ValueKey('sentence-translation')), '안녕하세요');
      await tester.pump();

      expect(tester.widget<FilledButton>(find.byKey(button)).onPressed, isNull,
          reason: '둘이 어긋나면 발음을 어느 쪽에 맞출지 알 수 없다');
    });

    testWidgets('한 번 채운 뒤에도 다시 받을 수 있다', (tester) async {
      // 자동으로 채운 값은 재료로 치지 않는다. 세면 다시 받기가 죽는다.
      await tester.pumpWidget(withSubscription(
          AddSentenceScreen(language: '일본어', assist: _CompleteAssist())));
      await tester.pump();

      await tester.enterText(
          find.byKey(const ValueKey('sentence-translation')), '안녕하세요');
      await tester.pump();
      await tester.tap(find.byKey(button));
      await tester.pump();
      await tester.pump();

      expect(tester.widget<FilledButton>(find.byKey(button)).onPressed,
          isNotNull,
          reason: '셋이 다 찼지만 손으로 적은 것은 하나다');
    });

    testWidgets('셋 다 손으로 적어 두면 꺼진다', (tester) async {
      await tester.pumpWidget(withSubscription(
          AddSentenceScreen(language: '일본어', assist: _CompleteAssist())));
      await tester.pump();

      await tester.enterText(
          find.byKey(const ValueKey('sentence-text')), 'こんにちは');
      await tester.enterText(
          find.byKey(const ValueKey('sentence-translation')), '안녕하세요');
      await tester.enterText(
          find.byKey(const ValueKey('sentence-pronunciation')), '곤니치와');
      await tester.pump();

      expect(tester.widget<FilledButton>(find.byKey(button)).onPressed, isNull,
          reason: '채울 칸이 없는데 누르면 하루 횟수만 버린다');
    });

    testWidgets('한글 소리 전용 칸은 없다', (tester) async {
      await tester.pumpWidget(withSubscription(
          AddSentenceScreen(language: '일본어', assist: _CompleteAssist())));
      await tester.pump();

      expect(find.byKey(const ValueKey('sentence-hangul')), findsNothing);
      expect(find.byKey(const ValueKey('transliterate')), findsNothing);
      expect(find.byKey(const ValueKey('compose-from-meaning')), findsNothing);
    });
  });

  // 앱바 오른쪽에 둔 횟수가 가운데 제목과 부딪히면 제목이 잘린다
  // (5차 542). 좁은 기기에서 둘 다 온전히 보여야 한다.
  testWidgets('좁은 기기에서도 제목과 횟수가 둘 다 보인다', (tester) async {
    tester.view.physicalSize = const Size(375 * 3, 667 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(withSubscription(AddSentenceScreen(
        language: '영어',
        assist: _UsageAssist(dailyLimit: 3, remainingToday: 1))));
    await tester.pump();

    expect(find.text('문장 추가'), findsOneWidget);
    expect(find.byKey(const ValueKey('usage-count')), findsOneWidget);
    expect(tester.takeException(), isNull);

    final title = tester.getRect(find.text('문장 추가'));
    final usage = tester.getRect(find.byKey(const ValueKey('usage-count')));
    expect(title.right, lessThanOrEqualTo(usage.left),
        reason: '제목과 횟수가 겹치면 둘 중 하나가 잘린다');
  });
}
