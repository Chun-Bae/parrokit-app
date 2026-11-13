// 보관함 검색(5차): 예전엔 입력칸만 있고 아무것도 찾지 않았다.
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
  });
}
