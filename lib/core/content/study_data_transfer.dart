// 내 문장과 내 단어를 백업 파일에 담고 다시 읽는다(5차 345, 사용자 요청).
//
// 백업은 클립과 자막(paro.db + 영상)만 담았다. 문장과 단어는 기기(또는 서버)에
// 따로 있어서 백업 파일에는 들어가지 않았고, 폰을 바꾸면 로그인하지 않은
// 사람은 잃었다.
//
// 예전 백업과 섞이지 않게 `study.json`이라는 파일 하나를 더 넣는다. 그 파일이
// 없는 예전 백업은 지금까지처럼 클립만 되돌린다.

import 'dart:convert';

import 'package:parrokit/core/content/my_sentence_store.dart';
import 'package:parrokit/core/content/my_word_store.dart';

/// 백업 안의 공부 자료 파일 이름.
const String studyDataFileName = 'study.json';

/// 이 파일의 형식 번호. 읽을 때 모르는 번호면 읽지 않는다.
const int studyDataVersion = 1;

/// 들어온 개수.
typedef StudyRestoreCount = ({int sentences, int words});

/// 내 문장·단어를 백업에 담을 글로 만든다.
Future<String> exportStudyData(
  String accountId, {
  bool sentences = true,
  bool words = true,
}) async {
  final sentenceList = sentences ? await MySentenceStore.load(accountId) : [];
  final wordList = words ? await MyWordStore.load(accountId) : [];
  return const JsonEncoder.withIndent('  ').convert({
    'version': studyDataVersion,
    'savedAt': DateTime.now().toIso8601String(),
    'sentences': [
      for (final s in sentenceList)
        {
          'language': s.language,
          'text': s.text,
          'translation': s.translation,
          'pronunciation': s.pronunciation,
          'topic': s.topic,
          'author': s.author,
        },
    ],
    'words': [
      for (final w in wordList)
        {
          'language': w.language,
          'word': w.word,
          'meaning': w.meaning,
          // 발음이 빠져 있었다(5차 566). 문장은 담는데 단어만 빠뜨려서,
          // 파일로 옮기거나 백업에서 되돌리면 적어 둔 발음이 사라졌다.
          // '뜻·발음 생성'으로 채운 것도 함께 사라진다.
          'pronunciation': w.pronunciation,
          'topic': w.topic,
          'synonyms': w.synonyms,
          'examples': [
            for (final e in w.examples)
              {'text': e.text, 'translation': e.translation},
          ],
        },
    ],
  });
}

/// 백업에서 읽은 글을 내 문장·단어로 되돌린다. 이미 있는 것은 건너뛴다.
///
/// 모르는 형식이거나 글이 깨졌으면 아무것도 넣지 않고 0을 돌려준다.
Future<StudyRestoreCount> importStudyData(
  String accountId,
  String source, {
  bool sentences = true,
  bool words = true,
}) async {
  Map<String, dynamic> data;
  try {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) return (sentences: 0, words: 0);
    data = decoded;
  } catch (_) {
    return (sentences: 0, words: 0);
  }
  final version = (data['version'] as num?)?.toInt() ?? 0;
  if (version <= 0 || version > studyDataVersion) {
    return (sentences: 0, words: 0);
  }

  var addedSentences = 0;
  if (sentences) {
    for (final item in (data['sentences'] as List? ?? const [])) {
      if (item is! Map) continue;
      final text = (item['text'] as String? ?? '').trim();
      final language = (item['language'] as String? ?? '').trim();
      if (text.isEmpty || language.isEmpty) continue;
      final ok = await MySentenceStore.add(
        accountId,
        language: language,
        text: text,
        translation: item['translation'] as String? ?? '',
        pronunciation: item['pronunciation'] as String? ?? '',
        topic: item['topic'] as String? ?? '내 문장',
        author: item['author'] as String? ?? '',
      );
      if (ok) addedSentences++;
    }
  }

  var addedWords = 0;
  if (words) {
    for (final item in (data['words'] as List? ?? const [])) {
      if (item is! Map) continue;
      final word = (item['word'] as String? ?? '').trim();
      final language = (item['language'] as String? ?? '').trim();
      if (word.isEmpty || language.isEmpty) continue;
      final result = await MyWordStore.add(
        accountId,
        language: language,
        word: word,
        meaning: item['meaning'] as String? ?? '',
        // 예전 파일에는 이 칸이 없다. 없으면 빈 값으로 둔다.
        pronunciation: item['pronunciation'] as String? ?? '',
        topic: item['topic'] as String? ?? '내 단어',
        synonyms: [
          for (final s in (item['synonyms'] as List? ?? const []))
            if (s is String) s,
        ],
        examples: [
          for (final e in (item['examples'] as List? ?? const []))
            if (e is Map)
              WordExample(
                text: e['text'] as String? ?? '',
                translation: e['translation'] as String? ?? '',
              ),
        ],
      );
      // savedOnDevice도 들어온 것이다. 서버에 못 올렸을 뿐(규칙 배포 전이거나
      // 오프라인) 단어는 이 기기에 저장돼 '내 단어'에 보인다. 전에는 added만
      // 세서, 단어가 멀쩡히 들어왔는데도 '새로 들어온 문장과 단어는 없어요'라고
      // 알렸다(5차).
      if (result != WordAddResult.duplicate) addedWords++;
    }
  }

  return (sentences: addedSentences, words: addedWords);
}

/// 백업에 든 것을 사람 말로 적는다('문장 12개 · 단어 3개').
String studyRestoreSummary(StudyRestoreCount count) {
  final parts = <String>[
    if (count.sentences > 0) '문장 ${count.sentences}개',
    if (count.words > 0) '단어 ${count.words}개',
  ];
  if (parts.isEmpty) return '새로 들어온 문장과 단어는 없어요.';
  // 이 안내는 백업 불러오기와 '문장·단어 파일에서 불러오기' 둘 다 쓴다.
  // 흐름 이름이 '불러오기'라 끝말도 맞춘다(5차 487).
  return '${parts.join(' · ')}를 불러왔어요.';
}

/// 백업·불러오기에서 하나도 고르지 않아 막혔을 때(5차 503).
///
/// 시트의 꺼진 단추 아래와 백업을 시작하는 쪽이 같은 말을 쓴다. 전에는
/// 시트가 '하나는 골라 주세요.', 서비스가 '백업할 것을 하나는 골라 주세요.'로
/// 갈려 있었다.
///
/// 빨강으로 적지 않는다. 아직 안 고른 것은 잘못이 아니라 할 일이다. 같은
/// 자리의 다른 화면(새 클립 '영상을 먼저 골라 주세요.', 음성 만들기 '읽을
/// 글을 적어 주세요.')도 흐린 글씨를 쓴다(5차 475의 규칙).
const String backupNoPartsMessage = '하나는 골라 주세요.';

/// 백업에 담을 것들(5차 345, 사용자 요청: 문장·단어·클립을 고르게).
class BackupParts {
  const BackupParts({
    this.clips = true,
    this.sentences = true,
    this.words = true,
  });

  const BackupParts.all() : this();

  final bool clips;
  final bool sentences;
  final bool words;

  bool get isEmpty => !clips && !sentences && !words;
  bool get needsStudyFile => sentences || words;

  BackupParts copyWith({bool? clips, bool? sentences, bool? words}) =>
      BackupParts(
        clips: clips ?? this.clips,
        sentences: sentences ?? this.sentences,
        words: words ?? this.words,
      );

  List<String> get names => [
        if (clips) 'clips',
        if (sentences) 'sentences',
        if (words) 'words',
      ];

  /// manifest에 적힌 목록을 읽는다. 적혀 있지 않은 예전 백업은 클립만 담겼다.
  static BackupParts fromManifest(Object? value) {
    if (value is! List) {
      return const BackupParts(sentences: false, words: false);
    }
    final set = {
      for (final v in value)
        if (v is String) v
    };
    return BackupParts(
      clips: set.contains('clips'),
      sentences: set.contains('sentences'),
      words: set.contains('words'),
    );
  }

  /// 고른 것과 백업에 든 것 둘 다인 것만.
  BackupParts intersect(BackupParts other) => BackupParts(
        clips: clips && other.clips,
        sentences: sentences && other.sentences,
        words: words && other.words,
      );

  @override
  bool operator ==(Object other) =>
      other is BackupParts &&
      other.clips == clips &&
      other.sentences == sentences &&
      other.words == words;

  @override
  int get hashCode => Object.hash(clips, sentences, words);

  @override
  String toString() => 'BackupParts(${names.join(',')})';
}
