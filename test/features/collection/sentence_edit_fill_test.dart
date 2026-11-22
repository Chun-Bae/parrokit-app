// 문장 고치기 창에서도 빈 칸을 받아 채운다(5차 565, 사용자 요청).
//
// 전에는 고치는 창에 생성 단추가 아예 없어서, 발음만 비어 있는 문장을
// 채우려면 지우고 문장 추가로 다시 넣어야 했다. 그러면 연습 기록과
// 친밀도가 함께 사라진다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/default_conversation_sentences.dart';
import 'package:parrokit/core/content/sentence_assist.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/sentence_collection_preview.dart';

class _FakeAssist implements SentenceAssist {
  _FakeAssist({this.limit = 3, this.remaining = 3});

  final int? limit;
  final int? remaining;

  /// 마지막으로 서버에 보낸 값.
  String? sentText;
  String? sentTranslation;
  String? sentPronunciation;

  @override
  int? get remainingToday => remaining;
  @override
  int? get dailyLimit => limit;
  @override
  int? get examplesRemainingToday => 10;
  @override
  int? get exampleDailyLimit => 10;
  @override
  int? get maxExamplesPerWord => 3;
  @override
  int? get exampleCredits => null;
  @override
  int? get assistCredits => null;

  @override
  Future<void> refreshUsage() async {}

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
  }) async {
    sentText = text;
    sentTranslation = translation;
    sentPronunciation = pronunciation;
    return const SentenceComplete(
      text: 'What does this word mean?',
      translation: '이 단어는 무슨 뜻이에요?',
      pronunciation: '왓 더즈 디스 워드 민',
    );
  }

  @override
  Future<WordSuggestion> suggestWord({
    required String language,
    required String word,
    List<String> existingExamples = const [],
    int count = 1,
  }) async =>
      const WordSuggestion();
}

DefaultConversationSentence _sentence({
  String text = 'What does this word mean?',
  String translation = '이 단어는 무슨 뜻이에요?',
  String pronunciation = '',
}) =>
    DefaultConversationSentence(
      id: 's1',
      language: '영어',
      text: text,
      translation: translation,
      pronunciation: pronunciation,
      topic: '일상',
    );

Future<void> _open(
  WidgetTester tester,
  DefaultConversationSentence sentence,
  SentenceAssist assist,
) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SentenceEditDialog(sentence: sentence, assist: assist),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('빈 발음을 받아 채운다', (tester) async {
    final assist = _FakeAssist();
    await _open(tester, _sentence(), assist);

    await tester.tap(find.byKey(const ValueKey('edit-sentence-fill')));
    await tester.pumpAndSettle();

    // 적혀 있는 것은 그대로 보내고, 빈 칸만 채운다.
    expect(assist.sentText, 'What does this word mean?');
    expect(assist.sentTranslation, '이 단어는 무슨 뜻이에요?');
    expect(assist.sentPronunciation, '');
    expect(find.text('왓 더즈 디스 워드 민'), findsOneWidget);
  });

  testWidgets('적혀 있는 칸은 덮어쓰지 않는다', (tester) async {
    final assist = _FakeAssist();
    await _open(tester, _sentence(pronunciation: '내가 적은 발음'), assist);

    final fill = tester.widget<ButtonStyleButton>(
        find.byKey(const ValueKey('edit-sentence-fill')));
    expect(fill.onPressed, isNull, reason: '빈 칸이 없으면 부를 까닭이 없다');
  });

  // 한도를 다 썼으면 눌러도 거절당한다. 누르기 전에 막고 까닭을 적는다.
  testWidgets('다 썼으면 막는다', (tester) async {
    final assist = _FakeAssist(limit: 3, remaining: 0);
    await _open(tester, _sentence(), assist);

    final fill = tester.widget<ButtonStyleButton>(
        find.byKey(const ValueKey('edit-sentence-fill')));
    expect(fill.onPressed, isNull);
  });

  testWidgets('남은 횟수를 머리에 적는다', (tester) async {
    await _open(tester, _sentence(), _FakeAssist());

    expect(find.byKey(const ValueKey('edit-sentence-usage')), findsOneWidget);
  });
}
