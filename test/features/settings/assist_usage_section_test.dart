// 더보기 지갑 아래의 '오늘 쓴 자동 채우기'(사용자 요청).
//
// 패롯·크래커는 잔액을 볼 수 있는데 하루 한도는 볼 곳이 없었다. 단어나
// 문장 창을 열어야만 '오늘 2/3회 사용'이 보였고, 다 쓴 뒤에야 알게 됐다.
//
// 뜻·발음과 예문은 서로 다른 축이라 나눠 적는다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/content/assist_usage_text.dart';
import 'package:parrokit/core/content/example_credits.dart';
import 'package:parrokit/core/content/sentence_assist.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/features/settings/more/presentation/sections/assist_usage_section.dart';
import 'package:parrokit/features/settings/subscription/domain/subscription_quota.dart';
import 'package:parrokit/features/settings/subscription/domain/subscription_tier.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/data/models/user.dart';
import 'package:parrokit/features/settings/subscription/presentation/providers/subscription_provider.dart';

class _FakeAssist implements SentenceAssist {
  _FakeAssist({
    this.remainingToday,
    this.dailyLimit,
    this.examplesRemainingToday,
    this.exampleDailyLimit,
  });

  @override
  int? remainingToday;
  @override
  int? dailyLimit;
  @override
  int? examplesRemainingToday;
  @override
  int? exampleDailyLimit;
  @override
  int? get maxExamplesPerWord => 3;

  @override
  int? exampleCredits;

  @override
  int? assistCredits;

  int refreshCalls = 0;

  @override
  Future<void> refreshUsage() async {
    refreshCalls++;
  }

  @override
  Future<SentenceSuggestion> suggest(
          {required String language, required String text}) async =>
      const SentenceSuggestion();
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

class _FakeSubscription extends ChangeNotifier implements SubscriptionProvider {
  _FakeSubscription(this._tier);
  final SubscriptionTier _tier;

  @override
  SubscriptionTier get tier => _tier;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUser extends ChangeNotifier implements UserProvider {
  _FakeUser(this.parrots);
  final int parrots;

  @override
  AppUser? get currentUser => AppUser(id: 'uid-1', parrots: parrots);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 첫 호출은 늦게 간 척(타임아웃), 두 번째는 받아들인 척 한다.
class _FakeCredits implements ExampleCreditsService {
  _FakeCredits({this.failFirst = false});

  final bool failFirst;
  final seenIds = <String>[];

  @override
  Future<ExampleCreditsResult> buy({
    int packs = 1,
    String? requestId,
    bool assist = false,
  }) async {
    seenIds.add(requestId ?? '(없음)');
    if (failFirst && seenIds.length == 1) {
      throw const ExampleCreditsFailed(exampleCreditSlowMessage);
    }
    return const ExampleCreditsResult(credits: 10, bought: 10, spent: 3);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(
  WidgetTester tester,
  SentenceAssist assist, {
  SubscriptionTier tier = SubscriptionTier.free,
  int parrots = 10,
  ExampleCreditsService? credits,
}) async {
  final cs = ColorScheme.fromSeed(seedColor: Colors.blue);
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(colorScheme: cs, textTheme: appTextTheme(cs, isDark: false)),
    home: MultiProvider(
      providers: [
        ChangeNotifierProvider<SubscriptionProvider>.value(
            value: _FakeSubscription(tier)),
        ChangeNotifierProvider<UserProvider>.value(value: _FakeUser(parrots)),
      ],
      child: Scaffold(
          body: AssistUsageSection(assist: assist, credits: credits)),
    ),
  ));
  await tester.pumpAndSettle();
}

String _rowValue(WidgetTester tester, String key) => tester
    .widgetList<Text>(find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(Text),
    ))
    .last
    .data!;

void main() {
  group('숫자 적기', () {
    test('서버 값이 없으면 쓴 수를 모른다고 적는다', () {
      expect(assistUsageCount(null, 3, '번'), '— / 3번');
    });

    test('서버 값이 있으면 쓴 수와 한도를 적는다', () {
      expect(assistUsageCount(2, 3, '번'), '2 / 3번');
      expect(assistUsageCount(0, 500, '개'), '0 / 500개');
    });

    test('사 둔 몫은 같은 줄에 붙인다', () {
      expect(assistUsageCount(2, 3, '번', 10), '2 / 3번 +10');
      expect(assistUsageCount(null, 10, '개', 20), '— / 10개 +20');
      expect(assistUsageCount(2, 3, '번', 0), '2 / 3번');
    });
  });

  group('화면', () {
    testWidgets('두 한도를 따로 적는다', (tester) async {
      final assist = _FakeAssist(
        dailyLimit: 3,
        remainingToday: 1,
        exampleDailyLimit: 5,
        examplesRemainingToday: 5,
      );
      await _pump(tester, assist);

      expect(assist.refreshCalls, 1, reason: '열 때 한 번 물어본다');
      expect(find.text(assistUsageBasicsLabel), findsOneWidget);
      expect(find.text(assistUsageExamplesLabel), findsOneWidget);
      expect(_rowValue(tester, 'assist-usage-basics'), '2 / 3번');
      // 단위는 '번'으로 맞췄다(5차 562, 사용자 요청).
      expect(_rowValue(tester, 'assist-usage-examples'), '0 / 5번');
    });

    testWidgets('서버가 한도를 안 주면 단계 기본값으로 적는다', (tester) async {
      await _pump(tester, _FakeAssist(), tier: SubscriptionTier.pro);

      // 프로는 뜻·발음 60번, 예문 200개.
      expect(_rowValue(tester, 'assist-usage-basics'),
          '— / ${dailyAssistFor(SubscriptionTier.pro)}번');
      expect(_rowValue(tester, 'assist-usage-examples'),
          '— / ${dailyExamplesFor(SubscriptionTier.pro)}번');
    });

    testWidgets('못 읽으면 다시 물어볼 수 있게 한다', (tester) async {
      final assist = _FakeAssist();
      await _pump(tester, assist);

      expect(find.text(assistUsageUnknownLabel), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('assist-usage-retry')));
      await tester.pumpAndSettle();
      expect(assist.refreshCalls, 2);
    });

    testWidgets('읽었으면 안내만 적고 다시 묻기는 숨긴다', (tester) async {
      await _pump(
        tester,
        _FakeAssist(
          dailyLimit: 15,
          remainingToday: 15,
          exampleDailyLimit: 30,
          examplesRemainingToday: 30,
        ),
        tier: SubscriptionTier.light,
      );

      expect(find.byKey(const ValueKey('assist-usage-retry')), findsNothing);
      expect(find.byKey(const ValueKey('assist-usage-hint')), findsOneWidget);
    });

    testWidgets('무료 단계에는 구독 권유를 덧붙인다', (tester) async {
      await _pump(
        tester,
        _FakeAssist(
          dailyLimit: 3,
          remainingToday: 0,
          exampleDailyLimit: 5,
          examplesRemainingToday: 0,
        ),
      );

      final hint = tester
          .widget<Text>(find.byKey(const ValueKey('assist-usage-hint')))
          .data!;
      expect(hint, contains(assistUsageResetHint));
      expect(hint, contains('구독하면'));
    });
  });

  // 사 둔 몫을 줄 하나로 따로 뒀더니 같은 한도가 두 줄로 쪼개져 읽기
  // 어려웠다(사용자 지적). 같은 줄에 '+K'로 붙인다(5차 535).
  group('사 둔 몫', () {
    testWidgets('있으면 같은 줄에 덧붙인다', (tester) async {
      await _pump(
        tester,
        _FakeAssist(
          dailyLimit: 3,
          remainingToday: 13,
          exampleDailyLimit: 10,
          examplesRemainingToday: 25,
        )
          ..exampleCredits = 20
          ..assistCredits = 10,
      );

      // 하루 3번 중 0번 썼고 사 둔 10번이 더 있다.
      expect(_rowValue(tester, 'assist-usage-basics'), '0 / 3번 +10');
      // 하루 10개 중 5개 썼고 사 둔 20개가 더 있다.
      expect(_rowValue(tester, 'assist-usage-examples'), '5 / 10번 +20');
      expect(find.byKey(const ValueKey('assist-usage-credits')), findsNothing);
    });

    testWidgets('없으면 덧붙이지 않는다', (tester) async {
      await _pump(
        tester,
        _FakeAssist(
          dailyLimit: 3,
          remainingToday: 3,
          exampleDailyLimit: 10,
          examplesRemainingToday: 10,
        )
          ..exampleCredits = 0
          ..assistCredits = 0,
      );

      expect(_rowValue(tester, 'assist-usage-examples'), '0 / 10번');
    });

    // 남은 수에 사 둔 몫이 더해져 오는데 그대로 빼서 '-5 / 10개'가 떴다.
    testWidgets('쓴 수가 음수로 내려가지 않는다', (tester) async {
      await _pump(
        tester,
        _FakeAssist(
          dailyLimit: 3,
          remainingToday: 3,
          exampleDailyLimit: 10,
          examplesRemainingToday: 15,
        )..exampleCredits = 10,
      );

      expect(_rowValue(tester, 'assist-usage-examples'), '5 / 10번 +10');
    });
  });

  group('사기 단추', () {
    testWidgets('패롯이 넉넉하면 눌린다', (tester) async {
      await _pump(
        tester,
        _FakeAssist(
          dailyLimit: 3,
          remainingToday: 3,
          exampleDailyLimit: 10,
          examplesRemainingToday: 10,
        ),
        parrots: 10,
      );

      final button = tester.widget<FilledButton>(
          find.byKey(const ValueKey('assist-usage-buy')));
      expect(button.onPressed, isNotNull);
      expect(find.byKey(const ValueKey('assist-usage-buy-blocked')),
          findsNothing);
    });

    testWidgets('패롯이 모자라면 막고 까닭을 단추 아래에 적는다', (tester) async {
      await _pump(
        tester,
        _FakeAssist(
          dailyLimit: 3,
          remainingToday: 3,
          exampleDailyLimit: 10,
          examplesRemainingToday: 10,
        ),
        parrots: 1,
      );

      final button = tester.widget<FilledButton>(
          find.byKey(const ValueKey('assist-usage-buy')));
      expect(button.onPressed, isNull);
      final why = tester
          .widget<Text>(find.byKey(const ValueKey('assist-usage-buy-blocked')))
          .data!;
      expect(why, contains('2개 모자라요'));
    });
  });

  // 응답이 늦어 타임아웃이 나도 서버는 끝냈을 수 있다. 기기에서 그랬다 -
  // 패롯 3개가 깎였는데 화면은 '사지 못했어요'였다(5차 534). 다시 누를 때
  // 새 id를 만들면 두 번 깎인다.
  group('늦게 간 구매', () {
    testWidgets('다시 눌러도 같은 요청 id를 쓴다', (tester) async {
      final credits = _FakeCredits(failFirst: true);
      await _pump(
        tester,
        _FakeAssist(
          dailyLimit: 3,
          remainingToday: 3,
          exampleDailyLimit: 10,
          examplesRemainingToday: 10,
        ),
        credits: credits,
      );

      await tester.tap(find.byKey(const ValueKey('assist-usage-buy')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('assist-usage-buy')));
      await tester.pumpAndSettle();

      expect(credits.seenIds.length, 2);
      expect(credits.seenIds.first, credits.seenIds.last,
          reason: '두 번째 시도가 새 id를 만들면 두 번 깎인다');
    });

    testWidgets('받아들여지면 그 id는 버린다', (tester) async {
      final credits = _FakeCredits();
      await _pump(
        tester,
        _FakeAssist(
          dailyLimit: 3,
          remainingToday: 3,
          exampleDailyLimit: 10,
          examplesRemainingToday: 10,
        ),
        credits: credits,
      );

      await tester.tap(find.byKey(const ValueKey('assist-usage-buy')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('assist-usage-buy')));
      await tester.pumpAndSettle();

      expect(credits.seenIds.length, 2);
      expect(credits.seenIds.first == credits.seenIds.last, isFalse,
          reason: '끝난 구매와 새 구매가 같은 id를 쓰면 두 번째가 무시된다');
    });

    testWidgets('늦게 끝나도 남은 수를 다시 읽는다', (tester) async {
      final assist = _FakeAssist(
        dailyLimit: 3,
        remainingToday: 3,
        exampleDailyLimit: 10,
        examplesRemainingToday: 10,
      );
      await _pump(tester, assist, credits: _FakeCredits(failFirst: true));
      final before = assist.refreshCalls;

      await tester.tap(find.byKey(const ValueKey('assist-usage-buy')));
      await tester.pumpAndSettle();

      expect(assist.refreshCalls, before + 1,
          reason: '안 읽으면 들어온 몫이 화면에 안 보인다');
    });
  });
}
