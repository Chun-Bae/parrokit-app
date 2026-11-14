// 연습 알림에 쓸 문장을 고르는 창(5차).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/default_conversation_sentences.dart';
import 'package:parrokit/features/settings/more/presentation/widgets/reminder_sentence_picker.dart';

DefaultConversationSentence s(String id, String text) =>
    DefaultConversationSentence(
      id: id,
      language: '영어',
      text: text,
      translation: '뜻 $id',
      pronunciation: '',
      topic: '',
    );

void main() {
  final sentences = [s('a', 'Hello'), s('b', 'Bye'), s('c', 'Thanks')];

  Future<Set<String>?> open(WidgetTester tester,
      {Set<String> chosen = const {},
      List<DefaultConversationSentence>? list}) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Set<String>? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await showReminderSentencePicker(
                context: context,
                sentences: list ?? sentences,
                chosen: chosen,
              );
            },
            child: const Text('열기'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('문장을 골라 돌려준다', (tester) async {
    await open(tester);
    expect(find.text('고른 문장이 없으면 내 문장을 모두 써요'), findsOneWidget);

    await tester.tap(find.text('Hello'));
    await tester.pump();
    await tester.tap(find.text('Thanks'));
    await tester.pump();
    expect(find.text('2개를 골랐어요'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('reminder-pick-done')));
    await tester.pumpAndSettle();
    // 창이 닫히고 고른 것이 돌아온다.
    expect(find.text('알림에 쓸 문장'), findsNothing);
  });

  testWidgets('이미 고른 문장은 체크된 채로 열린다', (tester) async {
    await open(tester, chosen: {'b'});
    expect(find.text('1개를 골랐어요'), findsOneWidget);
    final box = tester.widget<CheckboxListTile>(
        find.ancestor(of: find.text('Bye'), matching: find.byType(CheckboxListTile)));
    expect(box.value, isTrue);
  });

  testWidgets('전체를 누르면 모두 고르고, 다시 누르면 비운다', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('reminder-pick-all')));
    await tester.pump();
    expect(find.text('3개를 골랐어요'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('reminder-pick-all')));
    await tester.pump();
    expect(find.text('고른 문장이 없으면 내 문장을 모두 써요'), findsOneWidget);
  });

  testWidgets('문장이 없으면 먼저 저장하라고 알린다', (tester) async {
    await open(tester, list: const []);
    expect(find.text('저장한 문장이 없어요. 문장을 먼저 저장해 주세요.'), findsOneWidget);
  });
}
