import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    String example = '',
    String exampleTranslation = '',
    String sourceSentenceId = '',
    List<WordExample>? examples,
    this.topic = '내 단어',
    this.addedAt,
  }) : examples = examples ??
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

  /// 예문 목록. 비어 있을 수 있다.
  final List<WordExample> examples;

  /// 첫 예문. 예전 저장 방식과 화면을 그대로 두려고 남긴다.
  String get example => examples.isEmpty ? '' : examples.first.text;
  String get exampleTranslation =>
      examples.isEmpty ? '' : examples.first.translation;

  /// 문장에서 저장했으면 그 문장 id.
  String get sourceSentenceId =>
      examples.isEmpty ? '' : examples.first.sourceSentenceId;

  final String topic;
  final DateTime? addedAt;

  Map<String, Object> toJson() => {
        'id': id,
        'language': language,
        'word': word,
        'meaning': meaning,
        // 예전 형식(예문 하나)도 함께 쓴다. 예전 앱이 읽을 수 있고 서버 규칙도
        // 이 이름을 본다.
        'example': example,
        'exampleTranslation': exampleTranslation,
        'sourceSentenceId': sourceSentenceId,
        'examples': [for (final e in examples) e.toJson()],
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
      // 예전 형식은 예문이 하나였다. examples가 없으면 그 하나를 쓴다.
      examples: parseWordExamples(
        json['examples'],
        legacyText: text('example'),
        legacyTranslation: text('exampleTranslation'),
        legacySentenceId: text('sourceSentenceId'),
      ),
      topic: text('topic').isEmpty ? '내 단어' : text('topic'),
      addedAt:
          added is int ? DateTime.fromMillisecondsSinceEpoch(added) : null,
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
    final seen = {for (final w in remote) '${w.language}|${_normalize(w.word)}'};
    final merged = [
      ...remote,
      for (final w in device)
        if (!seen.contains('${w.language}|${_normalize(w.word)}')) w,
    ];
    merged.sort((a, b) => (a.addedAt ?? DateTime(0))
        .compareTo(b.addedAt ?? DateTime(0)));
    return merged;
  }

  static Future<List<MyWord>> loadFor(String accountId, String language) async =>
      (await load(accountId))
          .where((w) => w.language == language)
          .toList(growable: false);

  static Future<WordAddResult> add(
    String accountId, {
    required String language,
    required String word,
    String meaning = '',
    String example = '',
    String exampleTranslation = '',
    String sourceSentenceId = '',
    List<WordExample>? examples,
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
      examples: clipWordExamples(given),
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
      device[index] = MyWord(
        id: device[index].id,
        language: device[index].language,
        word: device[index].word,
        meaning: clipped,
        examples: device[index].examples,
        topic: device[index].topic,
        addedAt: device[index].addedAt,
      );
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
const int examplesMaxCount = 5;

/// 빈 예문을 버리고, 길이와 개수를 한도 안으로 줄인다.
List<WordExample> clipWordExamples(List<WordExample> examples) => [
      for (final e in examples)
        if (!e.isEmpty)
          WordExample(
            text: clipToLength(e.text.trim(), exampleMaxLength),
            translation:
                clipToLength(e.translation.trim(), exampleMaxLength),
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
