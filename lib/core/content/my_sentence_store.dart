import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'default_conversation_sentences.dart';
import 'sentence_activity_store.dart';

/// 사용자가 저장하거나 직접 추가한 "내 문장"을 계정별로 보관한다.
///
/// 앵무새는 기본 문장과 이 저장소의 문장 중 루틴이 켜진 것만 말한다.
/// 루틴 on/off와 말하기·연습 횟수는 [SentenceActivityStore]가 같은 id로 관리한다.
class MySentenceStore {
  MySentenceStore._();

  static String _key(String accountId) => 'parrokit.my_sentences.v1.$accountId';

  static String idFor(String language, String text) =>
      'my-$language-${text.trim().hashCode.toUnsigned(32)}';

  static Future<List<DefaultConversationSentence>> load(
    String accountId,
  ) async {
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

  /// 같은 언어에 같은 문장이 이미 있으면 추가하지 않고 false를 돌려준다.
  static Future<bool> add(
    String accountId, {
    required String language,
    required String text,
    String translation = '',
    String pronunciation = '',
    String topic = '내 문장',
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
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
    ));
    await _save(accountId, all);
    return true;
  }

  static Future<void> remove(String accountId, String id) async {
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

  static Map<String, String> _toJson(DefaultConversationSentence s) => {
        'id': s.id,
        'language': s.language,
        'text': s.text,
        'translation': s.translation,
        'pronunciation': s.pronunciation,
        'topic': s.topic,
      };

  static DefaultConversationSentence _fromJson(Map<String, dynamic> json) =>
      DefaultConversationSentence(
        id: json['id'] as String,
        language: json['language'] as String,
        text: json['text'] as String,
        translation: json['translation'] as String? ?? '',
        pronunciation: json['pronunciation'] as String? ?? '',
        topic: json['topic'] as String? ?? '내 문장',
      );
}
