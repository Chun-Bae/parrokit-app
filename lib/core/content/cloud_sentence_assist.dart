import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import 'sentence_assist.dart';

/// 서버 함수 `suggestSentenceInfo`(Gemini 2.5 Flash-Lite)를 부르는 도우미.
/// 두 기능이 같은 하루 횟수를 나눠 쓰고, 남은 횟수는 응답으로 받는다.
class CloudSentenceAssist implements SentenceAssist {
  CloudSentenceAssist({FirebaseFunctions? functions}) : _functions = functions;

  FirebaseFunctions? _functions;
  int? _remainingToday;
  int? _dailyLimit;

  @override
  int? get remainingToday => _remainingToday;

  @override
  int? get dailyLimit => _dailyLimit;

  @override
  Future<void> refreshUsage() async {
    try {
      await _call({'mode': 'status'});
    } catch (e) {
      // 횟수를 못 읽어도 기능 자체는 쓸 수 있으니 조용히 넘어간다.
      debugPrint('[assist] status failed: $e');
    }
  }

  Future<Map<String, dynamic>> _call(Map<String, Object> data) async {
    final HttpsCallable callable;
    try {
      callable = (_functions ??= FirebaseFunctions.instance)
          .httpsCallable('suggestSentenceInfo');
    } catch (e) {
      // Firebase가 준비되지 않았으면 서버를 부를 수 없다.
      debugPrint('[assist] unavailable: $e');
      throw const SentenceAssistUnavailable();
    }
    try {
      final result = await callable.call<Object?>(data);
      final body = result.data;
      if (body is! Map) throw StateError('unexpected response');
      final map = Map<String, dynamic>.from(body);
      final remaining = map['remainingToday'];
      if (remaining is num) _remainingToday = remaining.toInt();
      final limit = map['dailyLimit'];
      if (limit is num) _dailyLimit = limit.toInt();
      debugPrint('[assist] ${data['mode']} ok, remaining=$_remainingToday');
      return map;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[assist] ${data['mode']} failed: ${e.code} ${e.message}');
      switch (e.code) {
        case 'resource-exhausted':
          _remainingToday = 0;
          throw const SentenceAssistQuotaExceeded();
        case 'unauthenticated':
          throw const SentenceAssistUnavailable('로그인 후 쓸 수 있어요');
        default:
          rethrow;
      }
    }
  }

  @override
  Future<SentenceSuggestion> suggest({
    required String language,
    required String text,
  }) async {
    final map = await _call({
      'mode': 'suggest',
      'language': language,
      'text': text,
    });
    return SentenceSuggestion(
      translation: map['translation'] as String?,
      pronunciation: map['pronunciation'] as String?,
    );
  }

  @override
  Future<String?> transliterate({
    required String language,
    required String hangul,
  }) async {
    final map = await _call({
      'mode': 'transliterate',
      'language': language,
      'hangul': hangul,
    });
    return map['text'] as String?;
  }
}
