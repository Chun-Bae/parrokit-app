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
  Future<String?> transliterate(
          {required String language, required String hangul}) async =>
      null;

  @override
  Future<String?> compose({
    required String language,
    required String meaning,
  }) async =>
      null;

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

/// 뜻을 원문으로 바꿔 주는 도우미(5차 540).
class _ComposeAssist extends _UsageAssist {
  _ComposeAssist() : super(dailyLimit: 3, remainingToday: 3);

  final calls = <String>[];

  @override
  Future<String?> compose({
    required String language,
    required String meaning,
  }) async {
    calls.add(meaning);
    return 'こんにちは';
  }
}

void main() {
  testWidgets('한글 소리 전용 칸은 없다', (tester) async {
    // 발음칸이 같은 일을 하므로 걷어냈다(5차 541, 사용자 요청).
    await open(tester, '일본어');
    expect(find.byKey(const ValueKey('sentence-hangul')), findsNothing);
    expect(find.byKey(const ValueKey('auto-fill-now')), findsOneWidget);
  });

  testWidgets('발음을 적으면 단추가 생기고 준비 중이면 안내한다', (tester) async {
    await open(tester, '일본어');
    await tester.enterText(
        find.byKey(const ValueKey('sentence-pronunciation')), '곤니치와');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('transliterate')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('transliterate-message')), findsOneWidget);
    expect(find.textContaining('쓸 수 없어요'), findsWidgets);
  });

  testWidgets('채우기 버튼은 원문이 있어야 켜지고, 연결 전이면 안내하고 직접 입력할 수 있다', (tester) async {
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
    expect(find.textContaining('자동 채우기를 쓸 수 없어요'), findsOneWidget);

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

  testWidgets('영어에서도 발음으로 원문을 만들 수 있다', (tester) async {
    // 전에는 일본어·중국어에만 있었다. 영어도 '헬로 데어'를 적을 수 있다.
    await open(tester, '영어');
    expect(find.byKey(const ValueKey('transliterate')), findsNothing);
    await tester.enterText(
        find.byKey(const ValueKey('sentence-pronunciation')), '헬로 데어');
    await tester.pump();
    expect(find.byKey(const ValueKey('transliterate')), findsOneWidget);
  });

  testWidgets('서버가 알려 준 횟수를 버튼 옆에 "쓴 횟수 / 한도"로 보여준다', (tester) async {
    await tester.pumpWidget(withSubscription(AddSentenceScreen(
        language: '영어',
        assist: _UsageAssist(dailyLimit: 3, remainingToday: 2))));
    await tester.pump();
    expect(find.byKey(const ValueKey('usage-count')), findsOneWidget);
    expect(find.text('오늘 1/3회'), findsOneWidget);
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
    expect(find.text('오늘 3/3회'), findsOneWidget);
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
    FilledButton convert() => tester
        .widget<FilledButton>(find.byKey(const ValueKey('transliterate')));

    expect(find.byKey(const ValueKey('usage-loading')), findsOneWidget);
    expect(fill().onPressed, isNull, reason: '횟수를 읽는 중이다');
    expect(convert().onPressed, isNull, reason: '변환도 같은 횟수를 쓴다');

    assist.done.complete();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('usage-count')), findsOneWidget);
    expect(convert().onPressed, isNotNull);

    // 원문을 손으로 적으면 만들기 단추는 사라지고 채우기가 켜진다.
    await tester.enterText(
        find.byKey(const ValueKey('sentence-text')), 'こんにちは');
    await tester.pump();
    expect(find.byKey(const ValueKey('transliterate')), findsNothing);
    expect(fill().onPressed, isNotNull);
  });

  // 서버가 쉬다 깨는 첫 조회는 15초를 넘긴다. 그동안 변환 단추가 회색으로
  // 죽어만 있어 고장으로 보였다(5차 539, 사용자 지적).
  testWidgets('횟수를 읽는 동안 변환 단추가 돌아간다', (tester) async {
    final assist = _SlowUsageAssist();
    await tester.pumpWidget(withSubscription(
        AddSentenceScreen(language: '일본어', assist: assist)));
    await tester.pump();
    await tester.enterText(
        find.byKey(const ValueKey('sentence-pronunciation')), '곤니치와');
    await tester.pump();

    final button = find.byKey(const ValueKey('transliterate'));
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

  // 뜻만 알 때 원문을 만든다(5차 540, 사용자 요청).
  group('뜻으로 원문 만들기', () {
    testWidgets('뜻을 적으면 만들기 단추가 나오고 원문을 채운다', (tester) async {
      final assist = _ComposeAssist();
      await tester.pumpWidget(withSubscription(
          AddSentenceScreen(language: '일본어', assist: assist)));
      await tester.pump();

      expect(find.byKey(const ValueKey('compose-from-meaning')), findsNothing);

      await tester.enterText(
          find.byKey(const ValueKey('sentence-translation')), '안녕하세요');
      await tester.pump();
      expect(
          find.byKey(const ValueKey('compose-from-meaning')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('compose-from-meaning')));
      await tester.pump();
      await tester.pump();

      expect(assist.calls, ['안녕하세요']);
      expect(
          tester
              .widget<TextField>(
                  find.byKey(const ValueKey('sentence-text')))
              .controller!
              .text,
          'こんにちは');
    });

    testWidgets('원문을 손으로 적어 두면 단추가 없다', (tester) async {
      await tester.pumpWidget(withSubscription(
          AddSentenceScreen(language: '일본어', assist: _ComposeAssist())));
      await tester.pump();

      await tester.enterText(
          find.byKey(const ValueKey('sentence-translation')), '안녕하세요');
      await tester.enterText(
          find.byKey(const ValueKey('sentence-text')), '내가 적은 원문');
      await tester.pump();

      expect(find.byKey(const ValueKey('compose-from-meaning')), findsNothing);
    });

    testWidgets('영어에서도 쓸 수 있다', (tester) async {
      await tester.pumpWidget(withSubscription(
          AddSentenceScreen(language: '영어', assist: _ComposeAssist())));
      await tester.pump();

      await tester.enterText(
          find.byKey(const ValueKey('sentence-translation')), '안녕하세요');
      await tester.pump();

      expect(
          find.byKey(const ValueKey('compose-from-meaning')), findsOneWidget);
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
