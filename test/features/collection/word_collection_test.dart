import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/my_word_store.dart';
import 'package:parrokit/core/content/word_review_store.dart';
import 'package:parrokit/core/shared/theme/app_theme.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/word_collection_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    expect((await MyWordStore.load('guest')).single.word, 'nuance');
  });

  testWidgets('복습에서 알아요를 누르면 오늘 복습에서 빠진다', (tester) async {
    await MyWordStore.add('guest', language: '영어', word: 'subtle', meaning: '미묘한');
    await openWordTab(tester);
    await tester.tap(find.byKey(const ValueKey('start-word-review')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('review-word')), findsOneWidget);
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
}
