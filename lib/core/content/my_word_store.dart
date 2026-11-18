import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'word_base_form.dart';

/// 단어의 예문 하나. 같은 단어를 여러 문장에서 만나므로 여러 개를 둔다(5차).
@immutable
class WordExample {
  const WordExample({
    required this.text,
    this.translation = '',
    this.sourceSentenceId = '',
  });

  /// 예문 원문.
  final String text;

  /// 예문 뜻. 없으면 빈 값.
  final String translation;

  /// 문장에서 저장했으면 그 문장 id. 단어를 지워도 문장은 그대로다.
  final String sourceSentenceId;

  bool get isEmpty => text.trim().isEmpty;

  Map<String, Object> toJson() => {
        'text': text,
        'translation': translation,
        'sourceSentenceId': sourceSentenceId,
      };

  static WordExample? fromJson(Object? json) {
    if (json is! Map) return null;
    final text = json['text'];
    if (text is! String || text.trim().isEmpty) return null;
    String at(String key) => json[key] is String ? json[key] as String : '';
    return WordExample(
      text: text,
      translation: at('translation'),
      sourceSentenceId: at('sourceSentenceId'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WordExample &&
      other.text == text &&
      other.translation == translation &&
      other.sourceSentenceId == sourceSentenceId;

  @override
  int get hashCode => Object.hash(text, translation, sourceSentenceId);
}

/// 내 단어 하나. 문장에서 건졌으면 그 문장을 예문으로 함께 둔다.
@immutable
class MyWord {
  MyWord({
    required this.id,
    required this.language,
    required this.word,
    this.meaning = '',
    this.pronunciation = '',
    String example = '',
    String exampleTranslation = '',
    String sourceSentenceId = '',
    List<WordExample>? examples,
    List<String>? synonyms,
    this.topic = '내 단어',
    this.addedAt,
  })  : synonyms = synonyms ?? const [],
        examples = examples ??
            // 예전처럼 예문 하나만 넘기는 곳이 많아 그대로 받는다.
            (example.trim().isEmpty
                ? const []
                : [
                    WordExample(
                      text: example,
                      translation: exampleTranslation,
                      sourceSentenceId: sourceSentenceId,
                    )
                  ]);

  final String id;
  final String language;
  final String word;
  final String meaning;

  /// 한글로 적은 소리. 없을 수 있고, 예전에 저장한 단어에는 아예 없다
  /// (읽을 때 빈 값이 된다, 5차 468 사용자 요청).
  final String pronunciation;

  /// 예문 목록. 비어 있을 수 있다.
  final List<WordExample> examples;

  /// 유의어·동의어. 비어 있을 수 있다. 예전에 저장한 단어에는 없어서,
  /// 읽을 때 없으면 빈 목록이 된다(5차).
  final List<String> synonyms;

  /// 첫 예문. 예전 저장 방식과 화면을 그대로 두려고 남긴다.
  String get example => examples.isEmpty ? '' : examples.first.text;
  String get exampleTranslation =>
      examples.isEmpty ? '' : examples.first.translation;

  /// 문장에서 저장했으면 그 문장 id.
  String get sourceSentenceId =>
      examples.isEmpty ? '' : examples.first.sourceSentenceId;

  final String topic;
  final DateTime? addedAt;

  /// 한 가지만 바꾼 사본. 필드를 하나씩 다시 적다 보면 새 칸이 생길 때마다
  /// 빠뜨린 자리에서 값이 조용히 지워진다(5차 468에 발음을 더하며 겪었다).
  MyWord copyWith({
    String? meaning,
    String? pronunciation,
    List<WordExample>? examples,
    List<String>? synonyms,
  }) =>
      MyWord(
        id: id,
        language: language,
        word: word,
        meaning: meaning ?? this.meaning,
        pronunciation: pronunciation ?? this.pronunciation,
        examples: examples ?? this.examples,
        synonyms: synonyms ?? this.synonyms,
        topic: topic,
        addedAt: addedAt,
      );

  Map<String, Object> toJson() => {
        'id': id,
        'language': language,
        'word': word,
        'meaning': meaning,
        'pronunciation': pronunciation,
        // 예전 형식(예문 하나)도 함께 쓴다. 예전 앱이 읽을 수 있고 서버 규칙도
        // 이 이름을 본다.
        'example': example,
        'exampleTranslation': exampleTranslation,
        'sourceSentenceId': sourceSentenceId,
        'examples': [for (final e in examples) e.toJson()],
        'synonyms': synonyms,
        'topic': topic,
        if (addedAt != null) 'addedAt': addedAt!.millisecondsSinceEpoch,
      };

  static MyWord? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'], language = json['language'], word = json['word'];
    if (id is! String || language is! String || word is! String) return null;
    if (word.trim().isEmpty) return null;
    String text(String key) => json[key] is String ? json[key] as String : '';
    final added = json['addedAt'];
    return MyWord(
      id: id,
      language: language,
      word: word,
      meaning: text('meaning'),
      // 예전에 저장한 단어에는 이 칸이 없다. 없으면 빈 값이다.
      pronunciation: text('pronunciation'),
      // 예전 형식은 예문이 하나였다. examples가 없으면 그 하나를 쓴다.
      examples: parseWordExamples(
        json['examples'],
        legacyText: text('example'),
        legacyTranslation: text('exampleTranslation'),
        legacySentenceId: text('sourceSentenceId'),
      ),
      synonyms: parseWordSynonyms(json['synonyms']),
      topic: text('topic').isEmpty ? '내 단어' : text('topic'),
      addedAt: added is int ? DateTime.fromMillisecondsSinceEpoch(added) : null,
    );
  }
}

/// 저장된 예문 목록을 읽는다. [raw]가 없거나 비어 있으면 예전 형식(예문 하나)을
/// 쓴다. 두 형식이 섞여 있어도 읽을 수 있어야 해서 한곳에 모아 둔다.
List<WordExample> parseWordExamples(
  Object? raw, {
  String legacyText = '',
  String legacyTranslation = '',
  String legacySentenceId = '',
}) {
  if (raw is List) {
    final parsed = [
      for (final item in raw)
        if (WordExample.fromJson(item) case final e?) e,
    ];
    if (parsed.isNotEmpty) return parsed;
  }
  if (legacyText.trim().isEmpty) return const [];
  return [
    WordExample(
      text: legacyText,
      translation: legacyTranslation,
      sourceSentenceId: legacySentenceId,
    )
  ];
}

/// 로그인한 사용자의 단어를 서버(Firestore `words`)에 두는 쪽. 테스트에서
/// 가짜로 바꿀 수 있게 따로 뺐다.
abstract class WordCloud {
  Future<List<MyWord>> load(String ownerId);

  /// 같은 언어에 같은 단어가 이미 있으면 false.
  Future<bool> add(String ownerId, MyWord word);

  /// 뜻만 고친다. 규칙(firestore.rules의 words)에서 update를 허용한다.
  Future<void> setMeaning(String id, String meaning);

  /// 발음만 고친다(5차 468).
  Future<void> setPronunciation(String id, String pronunciation);

  /// 유의어만 고친다(5차).
  Future<void> setSynonyms(String id, List<String> synonyms);

  /// 예문 목록을 통째로 바꾼다(예문 더하기·지우기).
  Future<void> setExamples(String id, List<WordExample> examples);
  Future<void> remove(String id);
}

enum WordAddResult {
  added,

  /// 같은 언어에 같은 단어가 이미 있다.
  duplicate,

  /// 서버에 저장하지 못해 이 기기에만 저장했다(규칙 배포 전이거나 오프라인).
  savedOnDevice,
}

/// 사용자가 모은 "내 단어"를 계정별로 보관한다. 문장(MySentenceStore)과 같은 방식:
/// 로그인하면 [cloud], 게스트(`guest`)는 이 기기. 로그인했는데 서버 저장이
/// 실패하면 잃어버리지 않게 이 기기에 남기고, 읽을 때 둘을 합쳐 보여준다.
class MyWordStore {
  MyWordStore._();

  static WordCloud? cloud;

  /// 단어가 바뀌면 오른다. 목록 화면이 듣고 다시 읽는다.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static bool _useCloud(String accountId) =>
      cloud != null && accountId.isNotEmpty && accountId != 'guest';

  static String _key(String accountId) => 'parrokit.my_words.v1.$accountId';

  static String _normalize(String word) => word.trim().toLowerCase();

  static String idFor(String language, String word) =>
      'word-$language-${_normalize(word).hashCode.toUnsigned(32)}';

  static Future<List<MyWord>> _loadDevice(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(accountId));
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [
        for (final item in decoded)
          if (MyWord.fromJson(item) case final word?) word,
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveDevice(String accountId, List<MyWord> words) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key(accountId), jsonEncode([for (final w in words) w.toJson()]));
  }

  /// 오래된 순. 로그인 계정은 서버 단어 + 이 기기에만 남은 단어.
  static Future<List<MyWord>> load(String accountId) async {
    final device = await _loadDevice(accountId);
    if (!_useCloud(accountId)) return device;
    List<MyWord> remote;
    try {
      remote = await cloud!.load(accountId);
    } catch (_) {
      remote = const [];
    }
    final seen = {
      for (final w in remote) '${w.language}|${_normalize(w.word)}'
    };
    final merged = [
      ...remote,
      for (final w in device)
        if (!seen.contains('${w.language}|${_normalize(w.word)}')) w,
    ];
    merged.sort((a, b) =>
        (a.addedAt ?? DateTime(0)).compareTo(b.addedAt ?? DateTime(0)));
    return merged;
  }

  static Future<List<MyWord>> loadFor(
          String accountId, String language) async =>
      (await load(accountId))
          .where((w) => w.language == language)
          .toList(growable: false);

  static Future<WordAddResult> add(
    String accountId, {
    required String language,
    required String word,
    String meaning = '',
    String pronunciation = '',
    String example = '',
    String exampleTranslation = '',
    String sourceSentenceId = '',
    List<WordExample>? examples,
    List<String> synonyms = const [],
    String topic = '내 단어',
    DateTime? now,
  }) async {
    final trimmed = word.trim();
    if (trimmed.isEmpty) return WordAddResult.duplicate;
    final existing = await loadFor(accountId, language);
    if (existing.any((w) => _normalize(w.word) == _normalize(trimmed))) {
      return WordAddResult.duplicate;
    }
    // 서버 규칙(firestore.rules의 validWord) 길이 안으로 줄인다. 문장에서
    // 저장하면 예문·번역에 긴 문장이 그대로 들어가 규칙에 걸렸고, 그 단어는
    // 서버에 못 올라가 이 기기에만 남았다(5차). 입력칸 maxLength는 미리 채운
    // 글을 줄이지 않는다.
    final given = examples ??
        [
          WordExample(
            text: example,
            translation: exampleTranslation,
            sourceSentenceId: sourceSentenceId,
          )
        ];
    final entry = MyWord(
      id: idFor(language, trimmed),
      language: language,
      word: clipToLength(trimmed, wordMaxLength),
      meaning: clipToLength(meaning.trim(), meaningMaxLength),
      pronunciation: clipToLength(pronunciation.trim(), meaningMaxLength),
      examples: clipWordExamples(given),
      synonyms: clipWordSynonyms(synonyms),
      topic: clipToLength(topic, topicMaxLength),
      addedAt: now ?? DateTime.now(),
    );
    var result = WordAddResult.added;
    if (_useCloud(accountId)) {
      try {
        final added = await cloud!.add(accountId, entry);
        if (!added) return WordAddResult.duplicate;
        revision.value++;
        return WordAddResult.added;
      } catch (_) {
        result = WordAddResult.savedOnDevice;
      }
    }
    final device = await _loadDevice(accountId);
    await _saveDevice(accountId, [...device, entry]);
    revision.value++;
    return result;
  }

  /// 저장해 둔 단어의 뜻을 고친다. 고쳤으면 true.
  ///
  /// 전에는 뜻을 비워 둔 채 저장하면(문장에서 단어만 고르면 자주 그랬다)
  /// 나중에 적을 길이 없었다. 지우고 다시 넣는 수밖에 없었다(5차).
  static Future<bool> setMeaning(
    String accountId,
    String id,
    String meaning,
  ) async {
    final clipped = clipToLength(meaning.trim(), meaningMaxLength);
    final device = await _loadDevice(accountId);
    final index = device.indexWhere((w) => w.id == id);
    if (index >= 0) {
      // 뜻만 바꾼다. 나머지는 copyWith가 그대로 들고 온다(5차 468).
      device[index] = device[index].copyWith(meaning: clipped);
      await _saveDevice(accountId, device);
      revision.value++;
      return true;
    }
    if (_useCloud(accountId)) {
      try {
        await cloud!.setMeaning(id, clipped);
        revision.value++;
        return true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// 저장해 둔 단어의 유의어를 고친다. 고쳤으면 true.
  ///
  /// 추가할 때만 적을 수 있으면, 나중에 알게 된 유의어를 넣을 길이 없다(5차).
  static Future<bool> setSynonyms(
    String accountId,
    String id,
    List<String> synonyms,
  ) async {
    final clipped = clipWordSynonyms(synonyms);
    final device = await _loadDevice(accountId);
    final index = device.indexWhere((w) => w.id == id);
    if (index >= 0) {
      device[index] = device[index].copyWith(synonyms: clipped);
      await _saveDevice(accountId, device);
      revision.value++;
      return true;
    }
    if (_useCloud(accountId)) {
      try {
        await cloud!.setSynonyms(id, clipped);
        revision.value++;
        return true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// 발음만 고친다(5차 468, 사용자 요청).
  static Future<bool> setPronunciation(
    String accountId,
    String id,
    String pronunciation,
  ) async {
    final clipped = clipToLength(pronunciation.trim(), meaningMaxLength);
    final device = await _loadDevice(accountId);
    final index = device.indexWhere((w) => w.id == id);
    if (index >= 0) {
      device[index] = device[index].copyWith(pronunciation: clipped);
      await _saveDevice(accountId, device);
      revision.value++;
      return true;
    }
    if (_useCloud(accountId)) {
      try {
        await cloud!.setPronunciation(id, clipped);
        revision.value++;
        return true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// 이미 있는 단어에 예문 하나를 더한다(5차, 사용자 질문).
  ///
  /// 'projections'를 고를 때 단어장에 'projection'이 있으면, 새로 만들지 않고
  /// 그 단어에 이 문장을 예문으로 붙인다. 같은 문장이면 더하지 않는다.
  /// 고칠 수 있는 칸을 한 번에 저장한다(5차 469, 사용자 요청).
  ///
  /// 전에는 뜻·발음·유의어·예문을 각각 다른 창에서 고치고 저장도 따로
  /// 했다. 한 화면에서 고치게 되면서 저장도 한 번에 한다.
  static Future<bool> saveEdits(
    String accountId,
    String id, {
    required String meaning,
    required String pronunciation,
    required List<String> synonyms,
    required List<WordExample> examples,
  }) async {
    final nextMeaning = clipToLength(meaning.trim(), meaningMaxLength);
    final nextSound = clipToLength(pronunciation.trim(), meaningMaxLength);
    final nextSynonyms = clipWordSynonyms(synonyms);
    final nextExamples = clipWordExamples(examples);

    final device = await _loadDevice(accountId);
    final index = device.indexWhere((w) => w.id == id);
    if (index >= 0) {
      device[index] = device[index].copyWith(
        meaning: nextMeaning,
        pronunciation: nextSound,
        synonyms: nextSynonyms,
        examples: nextExamples,
      );
      await _saveDevice(accountId, device);
      revision.value++;
      return true;
    }
    if (_useCloud(accountId)) {
      try {
        await cloud!.setMeaning(id, nextMeaning);
        await cloud!.setPronunciation(id, nextSound);
        await cloud!.setSynonyms(id, nextSynonyms);
        await cloud!.setExamples(id, nextExamples);
        revision.value++;
        return true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  static Future<bool> addExample(
    String accountId,
    String id,
    WordExample example,
  ) async {
    if (example.text.trim().isEmpty) return false;
    final all = await load(accountId);
    final index = all.indexWhere((w) => w.id == id);
    if (index < 0) return false;
    final before = all[index];
    final already =
        before.examples.any((e) => e.text.trim() == example.text.trim());
    if (already) return false;
    if (before.examples.length >= examplesMaxCount) return false;
    final next = clipWordExamples([...before.examples, example]);

    final device = await _loadDevice(accountId);
    final deviceIndex = device.indexWhere((w) => w.id == id);
    if (deviceIndex >= 0) {
      device[deviceIndex] = before.copyWith(examples: next);
      await _saveDevice(accountId, device);
      revision.value++;
      return true;
    }
    if (_useCloud(accountId)) {
      try {
        await cloud!.setExamples(id, next);
        revision.value++;
        return true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// 저장해 둔 예문 하나를 뺀다(5차 328).
  ///
  /// 예문을 더할 수는 있는데 뺄 길이 없었다. '예문만 더하기'로 쌓이기 쉬워져
  /// 더 눈에 띄었다. 단어와 뜻·유의어는 그대로 둔다.
  static Future<bool> removeExample(
    String accountId,
    String id,
    int index,
  ) async {
    final all = await load(accountId);
    final found = all.indexWhere((w) => w.id == id);
    if (found < 0) return false;
    final before = all[found];
    if (index < 0 || index >= before.examples.length) return false;
    final next = [...before.examples]..removeAt(index);

    final device = await _loadDevice(accountId);
    final deviceIndex = device.indexWhere((w) => w.id == id);
    if (deviceIndex >= 0) {
      device[deviceIndex] = before.copyWith(examples: next);
      await _saveDevice(accountId, device);
      revision.value++;
      return true;
    }
    if (_useCloud(accountId)) {
      try {
        await cloud!.setExamples(id, next);
        revision.value++;
        return true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// 예문 하나를 고친다(5차 338, 사용자 요청: 이미 만든 단어도 예문을 고칠 수
  /// 있어야 한다). 글이 비면 고치지 않는다. 뺄 때는 [removeExample]을 쓴다.
  static Future<bool> updateExample(
    String accountId,
    String id,
    int index,
    WordExample example,
  ) async {
    if (example.text.trim().isEmpty) return false;
    final all = await load(accountId);
    final found = all.indexWhere((w) => w.id == id);
    if (found < 0) return false;
    final before = all[found];
    if (index < 0 || index >= before.examples.length) return false;
    final next = clipWordExamples([...before.examples]..[index] = example);

    final device = await _loadDevice(accountId);
    final deviceIndex = device.indexWhere((w) => w.id == id);
    if (deviceIndex >= 0) {
      device[deviceIndex] = before.copyWith(examples: next);
      await _saveDevice(accountId, device);
      revision.value++;
      return true;
    }
    if (_useCloud(accountId)) {
      try {
        await cloud!.setExamples(id, next);
        revision.value++;
        return true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// 단어장에서 이 낱말과 같거나 어형만 다른 단어들(5차, 사용자 요청).
  ///
  /// 같은 낱말이 먼저, 그다음이 어형만 다른 것들이다. 양쪽으로 본다:
  /// 고른 'projections'의 원형이 단어장에 있는 경우와, 단어장의
  /// 'projections'가 고른 'projection'에서 온 경우 둘 다 찾는다.
  static Future<List<MyWord>> findRelatedWords(
    String accountId, {
    required String language,
    required String word,
  }) async {
    final words = await loadFor(accountId, language);
    final typed = _normalize(word);
    final same = <MyWord>[];
    final related = <MyWord>[];

    final typedBases = canGuessBaseForm(language)
        ? guessBaseForms(word).map(_normalize).toSet()
        : <String>{};

    for (final w in words) {
      final saved = _normalize(w.word);
      if (saved == typed) {
        same.add(w);
        continue;
      }
      if (typedBases.contains(saved)) {
        related.add(w);
        continue;
      }
      if (canGuessBaseForm(language) &&
          guessBaseForms(w.word).map(_normalize).contains(typed)) {
        related.add(w);
      }
    }
    return [...same, ...related];
  }

  /// 같은 단어 하나만 필요할 때. 없으면 null.
  static Future<MyWord?> findSameOrBaseForm(
    String accountId, {
    required String language,
    required String word,
  }) async {
    final found =
        await findRelatedWords(accountId, language: language, word: word);
    return found.isEmpty ? null : found.first;
  }

  /// 단어만 지운다. 예문으로 붙은 원래 문장은 건드리지 않는다.
  static Future<void> remove(String accountId, String id) async {
    final device = await _loadDevice(accountId);
    final next = device.where((w) => w.id != id).toList();
    if (next.length != device.length) await _saveDevice(accountId, next);
    if (_useCloud(accountId) && next.length == device.length) {
      try {
        await cloud!.remove(id);
      } catch (_) {/* 다음에 다시 지울 수 있게 목록에는 그대로 둔다 */}
    }
    revision.value++;
  }
}

/// 단어 필드 길이 한도. firestore.rules의 validWord와 같아야 한다.
const int wordMaxLength = 80;
const int meaningMaxLength = 200;
const int exampleMaxLength = 300;
const int topicMaxLength = 40;

/// 한 단어에 둘 수 있는 예문 수. 서버에 올리는 양을 묶어 두려고 정한다.
/// 한 낱말이 들고 갈 수 있는 예문 수. 서버의 MAX_WORD_EXAMPLES와 같아야 한다.
/// 자동으로 예문을 만들 수 있게 되면서 5개로는 금방 찼다(5차 467, 사용자 요청).
const int examplesMaxCount = 10;

/// 예문 뜻만 적고 예문을 비워 둔 칸이 있을 때 막는 까닭(5차 504).
///
/// 저장은 빈 예문 칸을 버린다(칸만 열어 두고 저장해도 괜찮아야 하니까).
/// 그런데 **뜻만 적어 둔 칸도 함께 버려졌다.** 적어 둔 글이 말 한마디 없이
/// 사라져서, 저장하고 돌아오면 쓴 적 없는 것처럼 보였다.
/// 이제 그 칸이 있으면 저장을 막고 몇 번째 칸인지 짚는다.
///
/// [index]는 화면에 적힌 번호(1부터)다.
String wordExampleNeedsTextMessage(int index) =>
    '예문 $index를 적어 주세요. 뜻만 적으면 담지 못해요.';

/// 뜻만 적힌 첫 예문 칸의 번호(1부터). 없으면 null.
///
/// [texts]와 [meanings]는 길이가 같아야 한다.
int? wordExampleMissingTextAt(List<String> texts, List<String> meanings) {
  for (var i = 0; i < texts.length; i++) {
    final text = texts[i].trim();
    final meaning = i < meanings.length ? meanings[i].trim() : '';
    if (text.isEmpty && meaning.isNotEmpty) return i + 1;
  }
  return null;
}

/// 유의어 하나의 길이와 개수.
const int synonymMaxLength = 40;
const int synonymsMaxCount = 10;

/// 저장된 유의어 목록을 읽는다. 예전에 저장한 단어에는 이 칸이 없다.
List<String> parseWordSynonyms(Object? raw) {
  if (raw is! List) return const [];
  return clipWordSynonyms([
    for (final item in raw)
      if (item is String) item,
  ]);
}

/// 빈 것과 겹치는 것을 버리고, 길이와 개수를 한도 안으로 줄인다.
List<String> clipWordSynonyms(List<String> synonyms) {
  final seen = <String>{};
  final out = <String>[];
  for (final raw in synonyms) {
    final one = clipToLength(raw.trim(), synonymMaxLength);
    if (one.isEmpty || !seen.add(one)) continue;
    out.add(one);
    if (out.length >= synonymsMaxCount) break;
  }
  return out;
}

/// 사람이 적은 한 줄('big, large')을 목록으로 나눈다. 쉼표·가운뎃점으로 나눈다.
List<String> parseSynonymInput(String text) =>
    clipWordSynonyms(text.split(RegExp(r'[,，·/]')).toList());

/// 목록을 다시 한 줄로. 고치기 칸에 되돌려 넣을 때 쓴다.
String synonymInputText(List<String> synonyms) => synonyms.join(', ');

/// 빈 예문을 버리고, 길이와 개수를 한도 안으로 줄인다.
List<WordExample> clipWordExamples(List<WordExample> examples) => [
      for (final e in examples)
        if (!e.isEmpty)
          WordExample(
            text: clipToLength(e.text.trim(), exampleMaxLength),
            translation: clipToLength(e.translation.trim(), exampleMaxLength),
            sourceSentenceId: e.sourceSentenceId,
          ),
    ].take(examplesMaxCount).toList();

/// [text]를 UTF-16 길이 [max] 안으로 자른다. 이모지 같은 두 칸짜리 글자를
/// 반으로 자르지 않는다.
String clipToLength(String text, int max) {
  if (text.length <= max) return text;
  final buffer = StringBuffer();
  var length = 0;
  for (final rune in text.runes) {
    final size = rune > 0xFFFF ? 2 : 1;
    if (length + size > max) break;
    buffer.writeCharCode(rune);
    length += size;
  }
  return buffer.toString();
}
