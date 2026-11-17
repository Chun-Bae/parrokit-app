import 'dart:async';
import 'package:parrokit/core/shared/utils/remote_call_timeout.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import 'sentence_assist.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';

/// 서버 함수 `suggestSentenceInfo`(Gemini 2.5 Flash-Lite)를 부르는 도우미.
/// 두 기능이 같은 하루 횟수를 나눠 쓰고, 남은 횟수는 응답으로 받는다.
class CloudSentenceAssist implements SentenceAssist {
  CloudSentenceAssist({FirebaseFunctions? functions}) : _functions = functions;

  /// 서버가 대답하지 않을 때 기다릴 시간(5차 446).
  ///
  /// 전에는 기다림에 끝이 없었다. 서버가 조용하면 '횟수 확인 중…'이 영영
  /// 남고, 뜻 채우기도 돌아가는 표시만 남은 채 멈춘다. 목소리 목록(395)과
  /// 챗봇 사용량(429)에서 고친 것과 같은 결함이다.
  ///
  /// 횟수만 묻는 것은 짧게, 글을 만들어 받는 것은 길게 기다린다.
  /// 기다릴 시간은 앱이 쓰는 한 곳에서 가져온다(5차 454). 여기만 8초라
  /// 서버가 깨어나는 첫 호출에서 거의 늘 접혔다.
  static const usageTimeout = shortCallTimeout;
  static const suggestTimeout = Duration(seconds: 30);

  FirebaseFunctions? _functions;
  int? _remainingToday;
  int? _dailyLimit;

  @override
  int? get remainingToday => _remainingToday;

  @override
  int? get dailyLimit => _dailyLimit;

  @override
  Future<void> refreshUsage() async {
    // 한 번 접히면 조용히 한 번 더 묻는다(5차 454).
    //
    // 서버가 한동안 쉬다 깨는 첫 호출은 15초를 넘긴다. 기기에서 보니
    // 첫 조회는 늘 접히고 두 번째는 1초 안에 돌아왔다. 전에는 사용자가
    // '탭해서 다시 확인'을 직접 눌러야 숫자가 떴다.
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await _call({'mode': 'status'}, timeout: usageTimeout);
        return;
      } on TimeoutException catch (e) {
        AppLogger.w('[assist] 남은 횟수 조회 실패: $e');
        // 첫 번째면 서버가 깨어났을 테니 한 번 더 묻는다.
      } catch (e) {
        // 횟수를 못 읽어도 기능 자체는 쓸 수 있으니 조용히 넘어간다.
        AppLogger.w('[assist] 남은 횟수 조회 실패: $e');
        return;
      }
    }
  }

  Future<Map<String, dynamic>> _call(
    Map<String, Object> data, {
    Duration timeout = suggestTimeout,
  }) async {
    final HttpsCallable callable;
    try {
      callable = (_functions ??= FirebaseFunctions.instance)
          .httpsCallable('suggestSentenceInfo');
    } catch (e) {
      // Firebase가 준비되지 않았으면 서버를 부를 수 없다.
      AppLogger.w('[assist] Firebase 준비 안 됨: $e');
      throw const SentenceAssistUnavailable();
    }
    try {
      final result = await callable.call<Object?>(data).timeout(timeout);
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
      // 아래에서 코드별로 typed exception으로 바꿔 화면까지 전달한다.
      // 한도 초과처럼 예상되는 것도 섞여 있어 w로 남긴다.
      AppLogger.w('[assist] ${data['mode']} 실패: ${e.code} ${e.message}');
      switch (e.code) {
        case 'resource-exhausted':
          _remainingToday = 0;
          throw const SentenceAssistQuotaExceeded();
        case 'unauthenticated':
          throw const SentenceAssistUnavailable('로그인하면 쓸 수 있어요.');
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

  @override
  Future<WordSuggestion> suggestWord({
    required String language,
    required String word,
    List<String> existingExamples = const [],
    int count = 1,
  }) async {
    final map = await _call({
      'mode': 'word',
      'language': language,
      'text': word,
      // 이미 들고 있는 예문을 함께 보낸다. 서버가 이것과 겹치지 않게 만든다.
      'existingExamples': existingExamples,
      'count': count,
    });
    return WordSuggestion(
      translation: map['translation'] as String?,
      examples: _readExamples(map['examples']),
    );
  }

  static List<SuggestedExample> _readExamples(Object? raw) {
    if (raw is! List) return const [];
    final out = <SuggestedExample>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final text = item['text'];
      if (text is! String || text.trim().isEmpty) continue;
      final translation = item['translation'];
      out.add(SuggestedExample(
        text: text.trim(),
        translation: translation is String ? translation.trim() : '',
      ));
    }
    return out;
  }
}
