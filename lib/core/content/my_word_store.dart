import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 내 단어 하나. 문장에서 건졌으면 그 문장을 예문으로 함께 둔다.
@immutable
class MyWord {
  const MyWord({
    required this.id,
    required this.language,
    required this.word,
    this.meaning = '',
    this.example = '',
    this.exampleTranslation = '',
    this.sourceSentenceId = '',
    this.topic = '내 단어',
    this.addedAt,
  });

  final String id;
  final String language;
  final String word;
  final String meaning;

  /// 예문. 문장에서 저장했으면 그 문장 원문.
  final String example;
  final String exampleTranslation;

  /// 문장에서 저장했으면 그 문장 id. 단어를 지워도 문장은 그대로다.
  final String sourceSentenceId;
  final String topic;
  final DateTime? addedAt;

  Map<String, Object> toJson() => {
        'id': id,
        'language': language,
        'word': word,
        'meaning': meaning,
        'example': example,
        'exampleTranslation': exampleTranslation,
        'sourceSentenceId': sourceSentenceId,
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
      example: text('example'),
      exampleTranslation: text('exampleTranslation'),
      sourceSentenceId: text('sourceSentenceId'),
      topic: text('topic').isEmpty ? '내 단어' : text('topic'),
      addedAt:
          added is int ? DateTime.fromMillisecondsSinceEpoch(added) : null,
    );
  }
}

/// 로그인한 사용자의 단어를 서버(Firestore `words`)에 두는 쪽. 테스트에서
/// 가짜로 바꿀 수 있게 따로 뺐다.
abstract class WordCloud {
  Future<List<MyWord>> load(String ownerId);

  /// 같은 언어에 같은 단어가 이미 있으면 false.
  Future<bool> add(String ownerId, MyWord word);
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
    String topic = '내 단어',
    DateTime? now,
  }) async {
    final trimmed = word.trim();
    if (trimmed.isEmpty) return WordAddResult.duplicate;
    final existing = await loadFor(accountId, language);
    if (existing.any((w) => _normalize(w.word) == _normalize(trimmed))) {
      return WordAddResult.duplicate;
    }
    final entry = MyWord(
      id: idFor(language, trimmed),
      language: language,
      word: trimmed,
      meaning: meaning.trim(),
      example: example.trim(),
      exampleTranslation: exampleTranslation.trim(),
      sourceSentenceId: sourceSentenceId,
      topic: topic,
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
