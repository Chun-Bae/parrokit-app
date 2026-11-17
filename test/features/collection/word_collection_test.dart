import 'package:flutter/material.dart';
import 'package:parrokit/features/settings/more/presentation/web_document_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/my_word_store.dart';
import 'package:parrokit/core/content/sentence_assist.dart';
import 'package:parrokit/core/content/word_review_store.dart';
import 'package:parrokit/core/shared/theme/app_theme.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/word_collection_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAssist implements SentenceAssist {
  FakeAssist({
    this.translation = '미묘한 차이',
    this.pronunciation = '뉘앙스',
    this.examples = const [],
    this.quota = false,
  });
  final String translation;
  final String pronunciation;
  final List<SuggestedExample> examples;
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
  @override
  Future<WordSuggestion> suggestWord({
    required String language,
    required String word,
    List<String> existingExamples = const [],
    int count = 1,
  }) async {
    calls.add('$language:$word');
    if (quota) throw const SentenceAssistQuotaExceeded();
    return WordSuggestion(
      translation: translation,
      pronunciation: pronunciation,
      examples: examples,
    );
  }

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
  _reviewProgressTests();

  testWidgets('유의어를 적어 저장하면 상세에 칩으로 보인다', (tester) async {
    await openWordTab(tester);
    await tester.tap(find.byKey(const ValueKey('add-word')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('word-input')), 'huge');
    // 쉼표 대신 '추가'로 하나씩 넣는다(5차, 사용자 요청).
    await tester.enterText(find.byKey(const ValueKey('word-synonyms')), 'big');
    await tester.tap(find.byKey(const ValueKey('add-synonym')));
    await tester.pump();
    await tester.enterText(
        find.byKey(const ValueKey('word-synonyms')), 'large');
    await tester.tap(find.byKey(const ValueKey('add-synonym')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('save-word')));
    await tester.tap(find.byKey(const ValueKey('save-word')));
    await tester.pumpAndSettle();

    expect((await MyWordStore.load('guest')).single.synonyms, ['big', 'large']);

    await tester.tap(find.text('huge'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('word-detail-synonyms')), findsOneWidget);
    expect(find.text('big'), findsOneWidget);
    expect(find.text('large'), findsOneWidget);
  });

  testWidgets('상세에서 유의어를 나중에 적을 수 있다', (tester) async {
    await MyWordStore.add('guest', language: '영어', word: 'huge');
    await openWordTab(tester);
    await tester.tap(find.text('huge'));
    await tester.pumpAndSettle();

    // 아직 없으면 그렇게 적는다.
    expect(find.byKey(const ValueKey('word-detail-synonyms-empty')),
        findsOneWidget);
    // 469부터 뜻·발음·유의어·예문을 '고치기' 한 창에서 손본다.
    await tester.tap(find.byKey(const ValueKey('edit-word')));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('edit-word-synonym-input')), 'big');
    await tester.tap(find.byKey(const ValueKey('edit-word-synonym-add')));
    await tester.pump();
    await tester.enterText(
        find.byKey(const ValueKey('edit-word-synonym-input')), 'large');
    await tester.tap(find.byKey(const ValueKey('edit-word-synonym-add')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('edit-word-save')));
    await tester.pumpAndSettle();

    expect((await MyWordStore.load('guest')).single.synonyms, ['big', 'large']);
    expect(find.text('big'), findsOneWidget);
    expect(find.text('large'), findsOneWidget);
    // 적고 나면 '아직 적지 않았어요'가 사라진다.
    expect(find.byKey(const ValueKey('word-detail-synonyms-empty')),
        findsNothing);
  });

  testWidgets('웹에서 찾기는 단어를 적어야 열린다', (tester) async {
    await openWordTab(tester);
    await tester.tap(find.byKey(const ValueKey('add-word')));
    await tester.pumpAndSettle();

    // 단어가 비었으면 웹 화면을 열지 않는다(까닭은 토스트로 알린다 —
    // 토스트는 앱 전역 messenger를 쓰므로 여기서는 열리지 않는 것만 본다).
    await tester.tap(find.byKey(const ValueKey('search-word-web')));
    await tester.pumpAndSettle();
    expect(find.byType(WebDocumentScreen), findsNothing);
    // 시트는 그대로 열려 있다.
    expect(find.byKey(const ValueKey('word-input')), findsOneWidget);
    expect(wordSearchNeedsWordHint, isNotEmpty);
  });

  testWidgets('유의어가 없으면 상세에 그 칸을 두지 않는다', (tester) async {
    await MyWordStore.add('guest', language: '영어', word: 'slowly');
    await openWordTab(tester);
    await tester.tap(find.text('slowly'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('word-detail-synonyms')), findsNothing);
  });

  testWidgets('단어가 비면 저장이 꺼진 까닭을 버튼 아래에 적는다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await openAddSheet(tester, FakeAssist());

    final save = find.byKey(const ValueKey('save-word'));
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    expect(find.text(addWordNeedsWordHint), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('word-input')), 'nuance');
    await tester.pump();

    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    expect(find.text(addWordNeedsWordHint), findsNothing,
        reason: '적고 나면 안내가 사라진다');
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MyWordStore.cloud = null;
  });

  testWidgets('뜻이 비어 있는 단어도 상세에서 뜻을 적을 수 있다', (tester) async {
    await MyWordStore.add('guest',
        language: '영어',
        word: 'slowly',
        example: 'Could you speak more slowly?');
    await openWordTab(tester);

    await tester.tap(find.text('slowly'));
    await tester.pumpAndSettle();
    expect(find.text('뜻을 아직 적지 않았어요'), findsOneWidget);

    // 전에는 '단어 지우기'뿐이라, 뜻을 안 적고 저장하면 지우고 다시 넣는
    // 수밖에 없었다.
    await tester.tap(find.byKey(const ValueKey('edit-word')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('edit-word-meaning-input')), '천천히');
    await tester.tap(find.byKey(const ValueKey('edit-word-save')));
    await tester.pumpAndSettle();

    expect(find.text('천천히'), findsWidgets);
    expect(find.text('뜻을 아직 적지 않았어요'), findsNothing);
    expect((await MyWordStore.load('guest')).single.meaning, '천천히');
  });

  testWidgets('고치기 한 창에서 뜻·발음을 함께 바꾼다(5차 469)', (tester) async {
    await MyWordStore.add('guest',
        language: '영어', word: 'nuance', meaning: '미묘한 차이');
    await openWordTab(tester);

    await tester.tap(find.text('nuance'));
    await tester.pumpAndSettle();
    // 항목마다 단추가 서 있던 것을 '고치기' 하나로 모았다.
    expect(find.byKey(const ValueKey('edit-word')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('edit-word')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('edit-word-meaning-input')), '뉘앙스');
    await tester.enterText(
        find.byKey(const ValueKey('edit-word-pronunciation-input')), '뉘앙스');
    await tester.tap(find.byKey(const ValueKey('edit-word-save')));
    await tester.pumpAndSettle();

    final saved = (await MyWordStore.load('guest')).single;
    expect(saved.meaning, '뉘앙스');
    expect(saved.pronunciation, '뉘앙스');
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
    // 점만으로는 무엇을 세는지 알 수 없어 글자도 함께 보여 준다(5차).
    expect(find.text('복습 전'), findsOneWidget);
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
    // 한 단계 올라간 것이 목록에도 글자로 보인다.
    expect(find.text('복습 1단계'), findsOneWidget);
    final reviews = await WordReviewStore.loadAll('guest');
    expect(reviews.values.single.step, 1);
  });

  testWidgets('단어 상세에도 복습 단계가 보인다', (tester) async {
    await MyWordStore.add('guest', language: '영어', word: 'subtle', meaning: '미묘한');
    await openWordTab(tester);
    // 한 번 '알아요'로 골라 1단계로 올린다.
    await tester.tap(find.byKey(const ValueKey('start-word-review')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reveal-word')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('review-known')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('finish-word-review')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('subtle'));
    await tester.pumpAndSettle();
    final meta = tester.widget<Text>(
        find.byKey(const ValueKey('word-detail-meta')));
    // 목록과 같은 말로 적는다.
    expect(meta.data, contains('복습 1단계'));
  });

  // 한 번도 복습 안 한 단어인데 기한이 있으면, 상세에서 '복습 전'이 통째로
  // 사라졌다. 목록 줄은 '복습 전 · 오늘 다시'라고 하는데 상세는 '오늘
  // 복습할 단어'뿐이었다(5차 482).
  testWidgets('복습 전 단어도 상세에 단계를 적는다', (tester) async {
    await MyWordStore.add('guest', language: '영어', word: 'subtle', meaning: '미묘한');
    await openWordTab(tester);

    await tester.tap(find.text('subtle'));
    await tester.pumpAndSettle();
    final meta = tester.widget<Text>(
        find.byKey(const ValueKey('word-detail-meta')));
    expect(meta.data, contains('복습 전'));
  });

  testWidgets('복습 중에 닫기로 그만둘 수 있고 고른 답은 남는다', (tester) async {
    await MyWordStore.add('guest', language: '영어', word: 'subtle', meaning: '미묘한');
    await MyWordStore.add('guest', language: '영어', word: 'vivid', meaning: '생생한');
    await openWordTab(tester);
    await tester.tap(find.byKey(const ValueKey('start-word-review')));
    await tester.pumpAndSettle();

    // 첫 단어만 '알아요'로 고르고 닫는다.
    await tester.tap(find.byKey(const ValueKey('reveal-word')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('review-known')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('close-word-review')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('review-word')), findsNothing);
    final reviews = await WordReviewStore.loadAll('guest');
    expect(reviews.values.where((r) => r.step == 1).length, 1);
    // 남은 한 개는 아직 오늘 복습에 있다.
    expect(find.byKey(const ValueKey('start-word-review')), findsOneWidget);
  });

  testWidgets("'다시' 고른 단어는 창을 닫지 않고 한 번 더 본다", (tester) async {
    await MyWordStore.add('guest',
        language: '영어', word: 'subtle', meaning: '미묘한');
    await MyWordStore.add('guest',
        language: '영어', word: 'linger', meaning: '머무르다');
    await openWordTab(tester);
    await tester.tap(find.byKey(const ValueKey('start-word-review')));
    await tester.pumpAndSettle();

    // 하나는 '다시', 하나는 '알아요'.
    await tester.tap(find.byKey(const ValueKey('reveal-word')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('review-again')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reveal-word')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('review-known')));
    await tester.pumpAndSettle();

    expect(find.text('오늘 복습을 마쳤어요'), findsOneWidget);
    expect(find.text('알아요 1개 · 다시 1개'), findsOneWidget);

    // 전에는 '다시'를 골라도 창을 닫고 '시작'을 다시 눌러야 그 단어를
    // 또 볼 수 있었다.
    await tester.tap(find.byKey(const ValueKey('review-again-round')));
    await tester.pumpAndSettle();
    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('review-word')), findsOneWidget);
    // 두 바퀴째인 것을 제목이 말해 준다. 전에는 '오늘 복습 1 / 1'이라
    // 처음부터 다시 도는 것처럼 보였다(5차).
    expect(find.text("'다시' 고른 단어"), findsOneWidget);
    expect(find.text('오늘 복습'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('reveal-word')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('review-known')));
    await tester.pumpAndSettle();
    expect(find.text('알아요 1개 · 다시 0개'), findsOneWidget);
    expect(find.text('다시 본 단어까지 끝냈어요'), findsOneWidget);
    expect(find.byKey(const ValueKey('review-again-round')), findsNothing);
  });

  testWidgets('모두 알아요면 한 번 더 버튼이 없다', (tester) async {
    await MyWordStore.add('guest',
        language: '영어', word: 'subtle', meaning: '미묘한');
    await openWordTab(tester);
    await tester.tap(find.byKey(const ValueKey('start-word-review')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reveal-word')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('review-known')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('review-again-round')), findsNothing);
    expect(find.byKey(const ValueKey('finish-word-review')), findsOneWidget);
  });

  testWidgets('단어 상세에서 지우면 목록에서 사라진다', (tester) async {
    await MyWordStore.add('guest', language: '영어', word: 'figure out');
    await openWordTab(tester);
    await tester.tap(find.text('figure out'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete-word')));
    await tester.pumpAndSettle();
    // 되돌릴 수 없어서 한 번 묻는다(5차 401).
    expect(find.byKey(const ValueKey('delete-word-confirm')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('delete-word-ok')));
    await tester.pumpAndSettle();
    expect(find.text('figure out'), findsNothing);
    expect(await MyWordStore.load('guest'), isEmpty);
  });

  testWidgets('뜻 채우기는 단어를 적어야 누를 수 있고 서버 뜻으로 채운다', (tester) async {
    final assist = FakeAssist();
    await openAddSheet(tester, assist);
    final fill = find.byKey(const ValueKey('fill-word-meaning'));
    // 222에서 입력칸 안의 아이콘을 이름 있는 버튼으로 바꿨다.
    // 472에서 예문 채우기를 떼어 내 단추가 둘이 됐다. 이것은 뜻·발음 쪽.
    expect(find.text('뜻·발음 채우기'), findsOneWidget);
    expect(find.text('예문 채우기'), findsOneWidget);
    expect(tester.widget<ButtonStyleButton>(fill).onPressed, isNull);
    await tester.enterText(find.byKey(const ValueKey('word-input')), 'nuance');
    await tester.pump();
    await tester.tap(fill);
    await tester.pumpAndSettle();
    expect(assist.calls, ['영어:nuance']);
    expect(find.text('미묘한 차이'), findsOneWidget);
  });

  testWidgets('단어가 없어 막혔으면 그 까닭을 적는다(5차 474)', (tester) async {
    await openAddSheet(tester, FakeAssist());
    await tester.pumpAndSettle();

    // 단추가 흐린데 까닭이 없으면 쓸 수 없는 기능인 줄 안다.
    expect(find.text(wordFillNeedsWordHint), findsWidgets);
    for (final key in ['fill-word-meaning', 'fill-word-examples']) {
      final button = tester.widget<ButtonStyleButton>(find.byKey(ValueKey(key)));
      expect(button.onPressed, isNull, reason: key);
    }

    await tester.enterText(find.byKey(const ValueKey('word-input')), 'nuance');
    await tester.pump();

    // 적고 나면 무엇을 채우는지로 바뀐다.
    expect(find.text(wordFillNeedsWordHint), findsNothing);
    expect(find.text(wordFillBasicsHint), findsOneWidget);
    expect(find.text(wordFillExamplesHint), findsOneWidget);
  });

  testWidgets('남은 횟수를 버튼 옆에 적는다', (tester) async {
    await openAddSheet(tester, FakeAssist());
    await tester.pumpAndSettle();
    // FakeAssist는 하루 3회 중 2회가 남았다고 말한다.
    expect(find.text('오늘 1/3회 사용'), findsOneWidget);
  });

  test('횟수를 모르면 확인 중, 못 받아오면 아무 말도 안 한다', () {
    expect(wordAssistUsageLabel(used: null, limit: 3), '횟수 확인 중…');
    expect(wordAssistUsageLabel(used: 2, limit: 3), '오늘 2/3회 사용');
    expect(wordAssistUsageLabel(used: null, limit: null, failed: true), '');
  });

  testWidgets('이미 적은 뜻이 있으면 묻지 않고 그렇게 말한다(5차 368)', (tester) async {
    final assist = FakeAssist();
    await openAddSheet(tester, assist);
    await tester.enterText(find.byKey(const ValueKey('word-input')), 'nuance');
    await tester.enterText(find.byKey(const ValueKey('word-meaning')), '내 뜻');
    // 468부터 발음과 예문도 함께 채운다. 빈 칸이 하나라도 있으면 물으러
    // 가는 것이 맞으므로, 묻지 않는 것을 보려면 셋 다 차 있어야 한다.
    await tester.enterText(
        find.byKey(const ValueKey('word-pronunciation')), '내 발음');
    await tester.enterText(
        find.byKey(const ValueKey('word-example-0')), '내 예문');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('fill-word-meaning')));
    await tester.pumpAndSettle();
    expect(find.text('내 뜻'), findsOneWidget);
    // 전에는 서버에 묻고(하루 횟수를 쓰고) 아무 말 없이 끝났다.
    expect(assist.calls, isEmpty);
    // 시트가 아래를 덮어 SnackBar는 보이지 않는다. 시트 안에 적는다(5차 368).
    expect(find.byKey(const ValueKey('word-fill-note')), findsOneWidget);
    expect(find.text(wordMeaningAlreadyHint), findsOneWidget);
  });

  testWidgets('뜻이 비어 있을 때 횟수를 다 썼으면 그렇게 안내한다', (tester) async {
    final assist = FakeAssist(quota: true);
    await openAddSheet(tester, assist);
    await tester.enterText(find.byKey(const ValueKey('word-input')), 'nuance');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('fill-word-meaning')));
    await tester.pumpAndSettle();
    expect(assist.calls, ['영어:nuance']);
    expect(
        tester.widget<Text>(find.byKey(const ValueKey('word-fill-note'))).data,
        contains('오늘 자동 채우기를 모두 썼어요'));
  });

  test('다음 복습 안내는 달력 날짜로 센다', () {
    final lateNight = DateTime(2026, 11, 14, 23);
    // 기한 글은 기한만 말한다. 기한이 없으면 목록처럼 오늘로 본다(5차 482).
    expect(wordDueLabel(null, lateNight), '오늘 복습할 단어');
    expect(wordReviewStepLabel(0), '복습 전');
    expect(wordReviewStepLabel(2), '복습 2단계');
    expect(wordDueLabel(DateTime(2026, 11, 15), lateNight), '내일 복습');
    expect(wordDueLabel(DateTime(2026, 11, 14), lateNight), '오늘 복습할 단어');
    final morning = DateTime(2026, 11, 14, 10);
    expect(wordDueLabel(DateTime(2026, 11, 16), morning), '2일 뒤 복습');
    expect(wordDueLabel(DateTime(2026, 11, 10), morning), '오늘 복습할 단어');
  });
}

void _reviewProgressTests() {
  group('복습 진행 막대', () {
    test('머리말 숫자와 같은 몫을 채운다', () {
      // '1 / 3'이면 1/3만큼. 전에는 끝낸 개수를 써서 첫 단어에서 0이었다.
      expect(wordReviewProgress(index: 0, total: 3), closeTo(1 / 3, 1e-9));
      expect(wordReviewProgress(index: 1, total: 3), closeTo(2 / 3, 1e-9));
      expect(wordReviewProgress(index: 2, total: 3), 1);
    });

    test('다 끝내도 넘치지 않는다', () {
      expect(wordReviewProgress(index: 3, total: 3), 1);
      expect(wordReviewProgress(index: 99, total: 3), 1);
    });

    test('볼 단어가 없으면 가득 찬 것으로 둔다', () {
      expect(wordReviewProgress(index: 0, total: 0), 1);
    });
  });
}
