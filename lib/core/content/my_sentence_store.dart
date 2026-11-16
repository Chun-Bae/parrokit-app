import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'default_conversation_sentences.dart';
import 'sentence_activity_store.dart';
import 'sentence_cloud_store.dart';
import 'shared_sentence_repository.dart';

/// 사용자가 저장하거나 직접 추가한 "내 문장"을 계정별로 보관한다.
///
/// 로그인한 사용자는 [cloud](Firestore)에, 로그인하지 않은 게스트(`guest`)는 이 기기에 저장한다.
/// 앵무새는 기본 문장과 이 저장소의 문장 중 루틴이 켜진 것만 말한다.
/// 루틴 on/off와 말하기·연습 횟수는 [SentenceActivityStore]가 같은 id로 관리한다.
class MySentenceStore {
  MySentenceStore._();

  /// 로그인한 사용자의 문장을 보관하는 서버 저장소. 앱을 시작할 때 연결한다.
  /// 비어 있으면 모든 계정이 이 기기에 저장한다.
  static SentenceCloudStore? cloud;

  static bool _useCloud(String accountId) =>
      cloud != null && accountId.isNotEmpty && accountId != 'guest';

  static String _key(String accountId) => 'parrokit.my_sentences.v1.$accountId';

  static String idFor(String language, String text) =>
      'my-$language-${text.trim().hashCode.toUnsigned(32)}';

  static Future<List<DefaultConversationSentence>> load(
    String accountId,
  ) async {
    if (_useCloud(accountId)) return cloud!.load(accountId);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(accountId));
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [
        for (final item in decoded)
          if (item is Map<String, dynamic> && _isValid(item)) _fromJson(item),
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<List<DefaultConversationSentence>> loadFor(
    String accountId,
    String language,
  ) async {
    final all = await load(accountId);
    return all.where((s) => s.language == language).toList(growable: false);
  }

  /// 같은 언어의 같은 문장을 찾는다. 없으면 null.
  static Future<DefaultConversationSentence?> findByText(
    String accountId,
    String language,
    String text,
  ) async {
    final trimmed = text.trim();
    for (final item in await loadFor(accountId, language)) {
      if (item.text.trim() == trimmed) return item;
    }
    return null;
  }

  /// 같은 언어에 같은 문장이 이미 있으면 추가하지 않고 false를 돌려준다.
  static Future<bool> add(
    String accountId, {
    required String language,
    required String text,
    String translation = '',
    String pronunciation = '',
    String topic = '내 문장',
    String author = '',
    String authorId = '',
    String sourceSharedId = '',
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    if (_useCloud(accountId)) {
      final added = await cloud!.add(
        accountId,
        language: language,
        text: trimmed,
        translation: translation,
        pronunciation: pronunciation,
        topic: topic,
        author: author,
        authorId: authorId,
        sourceSharedId: sourceSharedId,
      );
      if (added) SentenceActivityStore.revision.value++;
      return added;
    }
    final id = idFor(language, trimmed);
    final all = await load(accountId);
    if (all.any((s) => s.id == id)) return false;
    all.add(DefaultConversationSentence(
      id: id,
      language: language,
      text: trimmed,
      translation: translation.trim(),
      pronunciation: pronunciation.trim(),
      topic: topic,
      author: author.trim(),
      addedAt: DateTime.now(),
    ));
    await _save(accountId, all);
    return true;
  }

  /// 저장해 둔 문장을 고친다(5차, 사용자 요청).
  ///
  /// id는 그대로 두므로 연습 기록·루틴 켜짐·친밀도가 따라온다. 같은 언어에
  /// 같은 문장이 이미 있으면 고치지 않고 false를 돌려준다.
  static Future<bool> update(
    String accountId,
    String id, {
    required String text,
    String pronunciation = '',
    String translation = '',
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    final all = await load(accountId);
    final index = all.indexWhere((s) => s.id == id);
    if (index < 0) return false;
    final before = all[index];
    final duplicated = all.any((s) =>
        s.id != id &&
        s.language == before.language &&
        s.text.trim() == trimmed);
    if (duplicated) return false;

    if (_useCloud(accountId)) {
      await cloud!.update(
        id,
        text: trimmed,
        pronunciation: pronunciation,
        translation: translation,
      );
      SentenceActivityStore.revision.value++;
      // 공개한 문장이면 둘러보기에 보이는 글도 같이 바뀐다.
      SharedSentenceRepository.revision.value++;
      return true;
    }

    all[index] = DefaultConversationSentence(
      id: before.id,
      language: before.language,
      text: trimmed,
      translation: translation.trim(),
      pronunciation: pronunciation.trim(),
      topic: before.topic,
      author: before.author,
      addedAt: before.addedAt,
    );
    await _save(accountId, all);
    return true;
  }

  /// 지금 둘러보기에 공개 중인 문장 id들. 기기에만 두는 게스트는 없다
  /// (공개는 로그인해야 한다).
  static Future<Set<String>> publishedIds(String accountId) async {
    if (!_useCloud(accountId)) return <String>{};
    return cloud!.publishedIds(accountId);
  }

  static Future<void> remove(String accountId, String id) async {
    if (_useCloud(accountId)) {
      await cloud!.remove(id);
      SentenceActivityStore.revision.value++;
      // 내가 공개한 문장이면 같은 문서가 지워져서 둘러보기에서도 사라진다.
      SharedSentenceRepository.revision.value++;
      return;
    }
    final all = await load(accountId);
    final next = all.where((s) => s.id != id).toList();
    if (next.length == all.length) return;
    await _save(accountId, next);
  }

  static Future<void> _save(
    String accountId,
    List<DefaultConversationSentence> sentences,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(accountId),
      jsonEncode([for (final s in sentences) _toJson(s)]),
    );
    // 앵무새와 목록 화면이 같은 신호로 다시 읽는다.
    SentenceActivityStore.revision.value++;
  }

  static bool _isValid(Map<String, dynamic> json) =>
      json['id'] is String &&
      json['language'] is String &&
      json['text'] is String &&
      (json['text'] as String).trim().isNotEmpty;

  static Map<String, Object> _toJson(DefaultConversationSentence s) => {
        if (s.addedAt != null) 'addedAt': s.addedAt!.millisecondsSinceEpoch,
        'id': s.id,
        'language': s.language,
        'text': s.text,
        'translation': s.translation,
        'pronunciation': s.pronunciation,
        'topic': s.topic,
        if (s.author.isNotEmpty) 'author': s.author,
      };

  static DefaultConversationSentence _fromJson(Map<String, dynamic> json) =>
      DefaultConversationSentence(
        id: json['id'] as String,
        language: json['language'] as String,
        text: json['text'] as String,
        translation: json['translation'] as String? ?? '',
        pronunciation: json['pronunciation'] as String? ?? '',
        topic: json['topic'] as String? ?? '내 문장',
        author: json['author'] as String? ?? '',
        addedAt: switch (json['addedAt']) {
          final num ms => DateTime.fromMillisecondsSinceEpoch(ms.toInt()),
          _ => null,
        },
      );
}
