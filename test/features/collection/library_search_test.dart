// 보관함 검색(5차): 예전엔 입력칸만 있고 아무것도 찾지 않았다.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/clip_sentence_match.dart';
import 'package:parrokit/core/content/default_conversation_sentences.dart';
import 'package:parrokit/core/content/my_word_store.dart';
import 'package:parrokit/features/collection/shell/presentation/library_search.dart';

const _sentence = DefaultConversationSentence(
  id: 's1',
  language: '영어',
  text: 'Nice to meet you',
  translation: '만나서 반가워요',
  pronunciation: '나이스 투 밋 유',
  topic: '인사',
);
const _other = DefaultConversationSentence(
  id: 's2',
  language: '일본어',
  text: 'おはようございます',
  translation: '안녕하세요',
  pronunciation: '오하요 고자이마스',
  topic: '인사',
);
final _word = MyWord(
    id: 'w1',
    language: '영어',
    word: 'meet',
    meaning: '만나다',
    example: 'Nice to meet you');

ClipSegmentRef _segment(int clipId, String title, String original,
        [String translation = '']) =>
    ClipSegmentRef(
      clipId: clipId,
      clipTitle: title,
      segmentId: clipId * 10,
      startMs: 0,
      endMs: 1000,
      original: original,
      translation: translation,
    );

final _data = LibrarySearchData(
  sentences: const [_sentence, _other],
  words: [_word],
  clips: const [(1, '여행 영어'), (2, '드라마 장면')],
  segments: [
    _segment(1, '여행 영어', 'Where is the station?', '역이 어디예요?'),
    _segment(2, '드라마 장면', 'Nice to meet you, too', '저도 반가워요'),
    _segment(2, '드라마 장면', 'See you', '또 봐요'),
  ],
);

void main() {
  group('searchLibrary', () {
    test('빈 검색어는 아무것도 찾지 않는다', () {
      expect(searchLibrary('  ', _data).isEmpty, isTrue);
    });

    test('문장·단어·클립 자막을 함께 찾고 대소문자는 무시한다', () {
      final r = searchLibrary('MEET', _data);
      expect(r.sentences.map((s) => s.id), ['s1']);
      expect(r.words.map((w) => w.id), ['w1']);
      expect(r.clips.single.clipId, 2);
      expect(r.clips.single.line, 'Nice to meet you, too');
    });

    test('뜻·해석으로도 찾고, 띄어쓰기는 무시한다', () {
      expect(searchLibrary('안녕 하세요', _data).sentences.map((s) => s.id),
          ['s2']);
      expect(searchLibrary('만나다', _data).words, hasLength(1));
      expect(searchLibrary('역이', _data).clips.single.clipId, 1);
    });

    test('클립은 제목이 맞으면 줄 없이 한 번만, 자막이 여러 줄 맞아도 한 번만', () {
      final byTitle = searchLibrary('여행', _data).clips;
      expect(byTitle.single.line, isNull);

      final byLines = searchLibrary('you', _data).clips;
      expect(byLines.map((c) => c.clipId), [2]);
    });

    test('종류마다 limit개까지만', () {
      final many = LibrarySearchData(
          clips: [for (var i = 0; i < 30; i++) (i, '클립 $i')]);
      final cut = searchLibrary('클립', many, limit: 5);
      expect(cut.clips, hasLength(5));
      expect(cut.moreClips, isTrue);
      expect(searchLibrary('클립 5', many, limit: 5).moreClips, isFalse);
    });
  });

  group('LibrarySearchSheet', () {
    Future<List<int>> open(WidgetTester tester) async {
      final opened = <int>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => SizedBox(
                  height: 500,
                  child: LibrarySearchSheet(
                    accountId: 'guest',
                    onOpenClip: opened.add,
                    load: () async => _data,
                  ),
                ),
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      return opened;
    }

    testWidgets('못 불러오면 다시 시도할 수 있고, 되면 결과가 나온다(5차 395)',
        (tester) async {
      var attempts = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 500,
            child: LibrarySearchSheet(
              accountId: 'guest',
              onOpenClip: (_) {},
              load: () async {
                attempts++;
                // 첫 번만 실패한다. '다시 시도'가 정말 다시 읽는지 본다.
                if (attempts == 1) throw Exception('network');
                return _data;
              },
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('불러오지 못했어요.'), findsOneWidget);
      final retry = find.byKey(const ValueKey('library-search-retry'));
      expect(retry, findsOneWidget);

      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.text('불러오지 못했어요.'), findsNothing);

      await tester.enterText(
          find.byKey(const ValueKey('library-search-field')), 'meet');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('library-search-results')),
          findsOneWidget);
    });

    testWidgets('치면 종류별로 결과가 나오고, 없으면 안내한다', (tester) async {
      await open(tester);
      expect(find.text('내 문장·단어와 클립 제목·자막에서 찾아요.'), findsOneWidget);

      await tester.enterText(
          find.byKey(const ValueKey('library-search-field')), 'meet');
      await tester.pump();
      expect(find.text('문장 1'), findsOneWidget);
      expect(find.text('단어 1'), findsOneWidget);
      expect(find.text('클립 1'), findsOneWidget);
      expect(find.text('드라마 장면'), findsOneWidget);

      await tester.enterText(
          find.byKey(const ValueKey('library-search-field')), 'zzz');
      await tester.pump();
      expect(find.byKey(const ValueKey('library-search-empty')), findsOneWidget);
      // 하나도 못 찾으면 고를 것이 없는 거르기 칩은 숨긴다(5차).
      expect(find.byKey(const ValueKey('library-search-kinds')), findsNothing);
    });

    testWidgets('한 종류만 걸러 빈 결과일 때 조사를 맞춰 말한다', (tester) async {
      await open(tester);
      await tester.enterText(
          find.byKey(const ValueKey('library-search-field')), 'e');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('library-search-kind-clips')));
      await tester.pump();
      await tester.enterText(
          find.byKey(const ValueKey('library-search-field')), '여행 영어');
      await tester.pump();

      final empty = find.byKey(const ValueKey('library-search-empty'));
      if (empty.evaluate().isNotEmpty) {
        // '클립이(가) 없어요'처럼 두 가지를 함께 쓰지 않는다.
        expect(tester.widget<Text>(empty).data!.contains('('), isFalse);
      }
    });

    testWidgets('클립을 누르면 검색 창을 닫고 그 클립을 연다', (tester) async {
      final opened = await open(tester);
      await tester.enterText(
          find.byKey(const ValueKey('library-search-field')), '역이');
      await tester.pump();
      await tester.tap(find.text('여행 영어'));
      await tester.pumpAndSettle();

      expect(opened, [1]);
      expect(find.byType(LibrarySearchSheet), findsNothing);
    });

    testWidgets('종류를 고르면 그 종류만 보여 준다', (tester) async {
      await open(tester);
      await tester.enterText(
          find.byKey(const ValueKey('library-search-field')), 'e');
      await tester.pump();
      // 처음에는 전체라 문장과 클립이 함께 보인다.
      expect(find.byKey(const ValueKey('library-search-kinds')), findsOneWidget);
      expect(find.text('여행 영어'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('library-search-kind-words')));
      await tester.pump();
      expect(find.text('여행 영어'), findsNothing);
    });
  });

  group('종류 고르기', () {
    test('고른 종류만 남는다', () {
      final all = searchLibrary('e', _data);
      expect(filterByKind(all, LibrarySearchKind.all), same(all));

      final onlyWords = filterByKind(all, LibrarySearchKind.words);
      expect(onlyWords.words, all.words);
      expect(onlyWords.sentences, isEmpty);
      expect(onlyWords.clips, isEmpty);

      final onlyClips = filterByKind(all, LibrarySearchKind.clips);
      expect(onlyClips.clips, all.clips);
      expect(onlyClips.sentences, isEmpty);
    });

    test('칩에 보이는 수는 종류별 결과 수이고 전체는 그 합이다', () {
      final all = searchLibrary('e', _data);
      expect(kindCount(all, LibrarySearchKind.sentences), all.sentences.length);
      expect(kindCount(all, LibrarySearchKind.words), all.words.length);
      expect(kindCount(all, LibrarySearchKind.clips), all.clips.length);
      expect(
          kindCount(all, LibrarySearchKind.all),
          all.sentences.length + all.words.length + all.clips.length);
    });

    test('더 있어서 잘랐으면 칩도 구역 머리와 같이 +를 붙인다(5차 393)', () {
      // 같은 글자가 든 문장을 한도보다 많이 만든다.
      final many = [
        for (var i = 0; i < 25; i++)
          DefaultConversationSentence(
            id: 'm$i',
            language: '영어',
            text: 'apple number $i',
            translation: '사과 $i',
            pronunciation: '애플 $i',
            topic: '인사',
          ),
      ];
      final results =
          searchLibrary('apple', LibrarySearchData(sentences: many));

      expect(results.sentences.length, 20);
      expect(results.moreSentences, isTrue);
      expect(kindHasMore(results, LibrarySearchKind.sentences), isTrue);
      expect(kindHasMore(results, LibrarySearchKind.all), isTrue);
      // 전에는 칩이 '문장 20개'라고만 해서 딱 20개뿐인 것처럼 보였다.
      expect(kindCountText(results, LibrarySearchKind.sentences), '20+');
      expect(kindCountText(results, LibrarySearchKind.all), '20+');
    });

    test('다 보여 줬으면 +를 붙이지 않는다', () {
      final results = searchLibrary('meet', _data);
      expect(kindHasMore(results, LibrarySearchKind.all), isFalse);
      expect(kindCountText(results, LibrarySearchKind.sentences),
          '${results.sentences.length}');
    });

    test('불러오지 못하면 다시 시도할 길을 준다', () {
      final source = File('lib/features/collection/shell/presentation/'
              'library_search.dart')
          .readAsStringSync();
      expect(source.contains("ValueKey('library-search-retry')"), isTrue);
      final code = source
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(code.contains('창을 닫고 다시 열어 주세요'), isFalse,
          reason: '다시 읽을 수 있는데 닫으라고만 하지 않는다');
    });

    test('목소리 시트도 닫으라고만 하지 않는다(5차 393)', () {
      final source = File('lib/features/content-studio/tts/presentation/'
              'widgets/tts_elevenlabs_voice_selection_sheet.dart')
          .readAsStringSync();
      expect(source.contains("ValueKey('retry-elevenlabs-voices')"), isTrue);
      final code = source
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(code.contains('창을 닫고 다시 열어 주세요'), isFalse);
      // 억양을 고를 때마다 목록을 다시 읽지 않도록 일을 들고 있는다.
      expect(code.contains('late Future<List<TtsElevenLabsVoice>> _voices'),
          isTrue);
    });
  });
}
