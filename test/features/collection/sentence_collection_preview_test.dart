import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/my_sentence_store.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/sentence_collection_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget app() => const MaterialApp(home: Scaffold(body: SentenceCollectionPreview()));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('추가한 문장이 내 문장 목록에 나타난다', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('내 문장'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('문장 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Brand new sentence');
    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();

    expect(find.text('Brand new sentence', skipOffstage: false), findsOneWidget);
  });

  testWidgets('둘러보기에서 저장한 문장이 내 문장에 나타난다', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.text('Could I get this to go?'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byTooltip('내 문장에 저장').first);
    await tester.pumpAndSettle();
    expect((await MySentenceStore.load('guest')).length, 1);

    await tester.scrollUntilVisible(find.text('내 문장'), -300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('내 문장'));
    await tester.pumpAndSettle();
    expect(find.text('Could I get this to go?', skipOffstage: false),
        findsOneWidget);
  });
}
