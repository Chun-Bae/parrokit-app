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
  Future<void> refreshUsage() async {}

  @override
  Future<SentenceSuggestion> suggest(
          {required String language, required String text}) async =>
      const SentenceSuggestion(translation: '안녕');

  @override
  Future<String?> transliterate(
          {required String language, required String hangul}) async =>
      null;
}

void main() {
  testWidgets('영어에는 한글 전사칸이 없다', (tester) async {
    await open(tester, '영어');
    expect(find.byKey(const ValueKey('sentence-hangul')), findsNothing);
    expect(find.byKey(const ValueKey('auto-fill-now')), findsOneWidget);
  });

  testWidgets('일본어는 한글 전사칸이 있고 준비 중이면 안내한다', (tester) async {
    await open(tester, '일본어');
    await tester.enterText(
        find.byKey(const ValueKey('sentence-hangul')), '곤니치와');
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
    expect(find.textContaining('횟수를 확인하지 못했어요'), findsOneWidget);

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

  testWidgets('언어를 고르면 한글 전사칸이 나타나고 사라진다', (tester) async {
    await open(tester, '영어');
    expect(find.byKey(const ValueKey('sentence-hangul')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('sentence-language')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('일본어').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sentence-hangul')), findsOneWidget);
  });

  testWidgets('서버가 알려 준 횟수를 버튼 옆에 "쓴 횟수 / 한도"로 보여준다', (tester) async {
    await tester.pumpWidget(withSubscription(AddSentenceScreen(
        language: '영어',
        assist: _UsageAssist(dailyLimit: 3, remainingToday: 2))));
    await tester.pump();
    expect(find.byKey(const ValueKey('usage-count')), findsOneWidget);
    expect(find.text('오늘 1/3회 사용'), findsOneWidget);
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
    expect(find.text('오늘 3/3회 사용'), findsOneWidget);
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
}
