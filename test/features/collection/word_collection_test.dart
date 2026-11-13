import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/my_word_store.dart';
import 'package:parrokit/core/content/sentence_assist.dart';
import 'package:parrokit/core/content/word_review_store.dart';
import 'package:parrokit/core/shared/theme/app_theme.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/word_collection_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAssist implements SentenceAssist {
  FakeAssist({this.translation = '미묘한 차이', this.quota = false});
  final String translation;
  final bool quota;
  final calls = <String>[];

  @override
  int? get remainingToday => 2;
  @override
  int? get dailyLimit => 3;
  @override
  Future<void> refreshUsage() async {}
  @override
  Future<SentenceSuggestion> suggest(
      {required String language, required String text}) async {
    calls.add('$language:$text');
    if (quota) throw const SentenceAssistQuotaExceeded();
    return SentenceSuggestion(translation: translation, pronunciation: '');
  }

  @override
  Future<String?> transliterate(
          {required String language, required String hangul}) async =>
      null;
}

Future<void> openAddSheet(WidgetTester tester, FakeAssist assist) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: AddWordSheet(accountId: 'guest', language: '영어', assist: assist),
    ),
  ));
  await tester.pump();
}

Future<void> openWordTab(WidgetTester tester) async {
  tester.view.physicalSize = const Size(440, 956);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    home: const Scaffold(body: WordCollectionPreview()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MyWordStore.cloud = null;
  });

  testWidgets('단어가 없으면 빈 화면과 단어 추가를 보여주고 예시 데이터는 없다', (tester) async {
    await openWordTab(tester);
    expect(find.text('아직 모은 단어가 없어요'), findsOneWidget);
    expect(find.text('hesitate'), findsNothing);
    expect(find.textContaining('예시 화면'), findsNothing);
    expect(find.byKey(const ValueKey('start-word-review')), findsNothing);
  });

  testWidgets('단어를 직접 추가하면 목록과 오늘 복습에 나온다', (tester) async {
    await openWordTab(tester);
    await tester.tap(find.byKey(const ValueKey('add-word')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('save-word')))
            .onPressed,
        isNull);
    await tester.enterText(find.byKey(const ValueKey('word-input')), 'nuance');
    await tester.enterText(find.byKey(const ValueKey('word-meaning')), '미묘한 차이');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('save-word')));
    await tester.pumpAndSettle();
    expect(find.text('nuance'), findsOneWidget);
    expect(find.text('미묘한 차이'), findsOneWidget);
    expect(find.text('오늘 다시 볼 단어 1개'), findsOneWidget);
    expect(find.text('뜻을 떠올려 보고 알았는지 골라요'), findsOneWidget);
    expect((await MyWordStore.load('guest')).single.word, 'nuance');
  });

  testWidgets('복습에서 알아요를 누르면 오늘 복습에서 빠진다', (tester) async {
    await MyWordStore.add('guest', language: '영어', word: 'subtle', meaning: '미묘한');
    await openWordTab(tester);
    await tester.tap(find.byKey(const ValueKey('start-word-review')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('review-word')), findsOneWidget);
    // 뜻을 보기 전에는 다시/알아요를 고를 수 없다.
    expect(find.byKey(const ValueKey('review-known')), findsNothing);
    expect(find.byKey(const ValueKey('review-again')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('reveal-word')));
    await tester.pump();
    expect(find.text('미묘한'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('review-known')));
    await tester.pumpAndSettle();
    expect(find.text('오늘 복습을 마쳤어요'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('finish-word-review')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('start-word-review')), findsNothing);
    final reviews = await WordReviewStore.loadAll('guest');
    expect(reviews.values.single.step, 1);
  });

  testWidgets('단어 상세에서 지우면 목록에서 사라진다', (tester) async {
    await MyWordStore.add('guest', language: '영어', word: 'figure out');
    await openWordTab(tester);
    await tester.tap(find.text('figure out'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete-word')));
    await tester.pumpAndSettle();
    expect(find.text('figure out'), findsNothing);
    expect(await MyWordStore.load('guest'), isEmpty);
  });

  testWidgets('뜻 채우기는 단어를 적어야 누를 수 있고 서버 뜻으로 채운다', (tester) async {
    final assist = FakeAssist();
    await openAddSheet(tester, assist);
    final fill = find.byKey(const ValueKey('fill-word-meaning'));
    expect(tester.widget<IconButton>(fill).onPressed, isNull);
    await tester.enterText(find.byKey(const ValueKey('word-input')), 'nuance');
    await tester.pump();
    await tester.tap(fill);
    await tester.pumpAndSettle();
    expect(assist.calls, ['영어:nuance']);
    expect(find.text('미묘한 차이'), findsOneWidget);
  });

  testWidgets('이미 적은 뜻은 덮지 않고, 횟수를 다 쓰면 안내한다', (tester) async {
    final assist = FakeAssist(quota: true);
    await openAddSheet(tester, assist);
    await tester.enterText(find.byKey(const ValueKey('word-input')), 'nuance');
    await tester.enterText(find.byKey(const ValueKey('word-meaning')), '내 뜻');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('fill-word-meaning')));
    await tester.pumpAndSettle();
    expect(find.text('내 뜻'), findsOneWidget);
    expect(find.textContaining('오늘 자동 채우기를 모두 썼어요'), findsOneWidget);
  });

  test('다음 복습 안내는 달력 날짜로 센다', () {
    final lateNight = DateTime(2026, 11, 14, 23);
    expect(wordDueLabel(null, lateNight), '아직 복습 전');
    expect(wordDueLabel(DateTime(2026, 11, 15), lateNight), '내일 복습');
    expect(wordDueLabel(DateTime(2026, 11, 14), lateNight), '오늘 복습할 단어');
    final morning = DateTime(2026, 11, 14, 10);
    expect(wordDueLabel(DateTime(2026, 11, 16), morning), '2일 뒤 복습');
    expect(wordDueLabel(DateTime(2026, 11, 10), morning), '오늘 복습할 단어');
  });
}
