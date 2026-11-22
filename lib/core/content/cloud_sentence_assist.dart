import 'dart:async';
import 'package:parrokit/core/shared/utils/remote_call_timeout.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

import 'sentence_assist.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';

/// 이 부름이 예문 한도를 쓰는지(5차 517).
///
/// 서버(sentenceAssist.ts)의 wantsExamples와 같은 규칙이어야 한다. 두 한도는
/// 모두 resource-exhausted로 거절되므로, 어느 쪽이 바닥났는지는 보낸 값으로
/// 가릴 수밖에 없다. 낱말을 묻되 count가 0이면 뜻·발음만 받는 것이라
/// 예문 한도를 쓰지 않는다.
bool assistCallWantsExamples(Map<String, Object> data) {
  final count = data['count'];
  return data['mode'] == 'word' && (count is! num || count > 0);
}

/// 서버가 날을 가르는 기준(sentenceAssist.ts의 todayKst). 한도는 한국
/// 자정에 새로 찬다.
String _todayKst() {
  final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
  return '${kst.year}-${kst.month}-${kst.day}';
}

/// 서버 함수 `suggestSentenceInfo`(Gemini 2.5 Flash-Lite)를 부르는 도우미.
/// 두 기능이 같은 하루 횟수를 나눠 쓰고, 남은 횟수는 응답으로 받는다.
class CloudSentenceAssist extends ChangeNotifier implements SentenceAssist {
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
  int? _examplesRemainingToday;
  int? _exampleDailyLimit;
  int? _maxExamplesPerWord;
  int? _exampleCredits;
  int? _assistCredits;

  @override
  int? get remainingToday => _remainingToday;

  @override
  int? get dailyLimit => _dailyLimit;

  @override
  int? get examplesRemainingToday => _examplesRemainingToday;

  @override
  int? get exampleDailyLimit => _exampleDailyLimit;

  @override
  int? get maxExamplesPerWord => _maxExamplesPerWord;

  @override
  int? get exampleCredits => _exampleCredits;

  @override
  int? get assistCredits => _assistCredits;

  /// 마지막으로 받아 둔 때. 같은 날 안에서 이만큼은 다시 묻지 않는다.
  ///
  /// 서버가 쉬다 깨는 첫 조회는 15초를 넘긴다(5차 454). 전에는 화면마다
  /// 제 인스턴스를 만들어 그 기다림을 따로 맞았다 - 더보기에서 받아 놓고
  /// 문장 추가를 열면 처음부터 다시 물었다. 이제 앱에 하나만 두고, 받아
  /// 둔 것이 아직 싱싱하면 그냥 쓴다(5차 564, 사용자 요청).
  static const usageFresh = Duration(minutes: 5);

  String? _fetchedDate;
  DateTime? _fetchedAt;

  /// 누구 것으로 받아 둔 숫자인지. 계정이 바뀌면 남의 숫자를 보여 줄 수
  /// 없으니 다시 묻는다.
  String? _fetchedUid;

  /// Firebase가 없는 곳(테스트)에서는 묻지 않는다. 거기서는 계정도 하나다.
  String? get _uid {
    try {
      return fb.FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  /// 지금 들고 있는 숫자를 믿어도 되는지.
  ///
  /// 날이 바뀌면 무조건 다시 묻는다. 서버는 한국 자정으로 날을 가르므로,
  /// 자정을 넘겨 들고 있으면 어제 쓴 수를 보여 주게 된다.
  bool get _usageFresh {
    final at = _fetchedAt;
    if (at == null || _fetchedDate != _todayKst()) return false;
    if (_fetchedUid != _uid) return false;
    return DateTime.now().difference(at) < usageFresh;
  }

  /// 받아 둔 숫자를 버린다. 다음 [refreshUsage]는 서버에 다시 묻는다.
  ///
  /// 패롯으로 몫을 사는 것은 다른 함수(exampleCredits)라 이 객체가 알 수
  /// 없다. 산 직후에는 이것을 불러야 새 몫이 보인다.
  void invalidateUsage() {
    _fetchedAt = null;
  }

  /// 지금 받은 숫자가 누구 것이고 언제 것인지 적어 둔다.
  void _mark() {
    _fetchedDate = _todayKst();
    _fetchedAt = DateTime.now();
    _fetchedUid = _uid;
  }

  @override
  Future<void> refreshUsage() async {
    if (_usageFresh) return;
    // 한 번 접히면 조용히 한 번 더 묻는다(5차 454).
    //
    // 서버가 한동안 쉬다 깨는 첫 호출은 15초를 넘긴다. 기기에서 보니
    // 첫 조회는 늘 접히고 두 번째는 1초 안에 돌아왔다. 전에는 사용자가
    // '탭해서 다시 확인'을 직접 눌러야 숫자가 떴다.
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await _call({'mode': 'status'}, timeout: usageTimeout);
        _mark();
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
    final wantsExamples = assistCallWantsExamples(data);
    try {
      final result = await callable.call<Object?>(data).timeout(timeout);
      final body = result.data;
      if (body is! Map) throw StateError('unexpected response');
      final map = Map<String, dynamic>.from(body);
      final remaining = map['remainingToday'];
      if (remaining is num) _remainingToday = remaining.toInt();
      final limit = map['dailyLimit'];
      if (limit is num) _dailyLimit = limit.toInt();
      final examplesRemaining = map['examplesRemainingToday'];
      if (examplesRemaining is num) {
        _examplesRemainingToday = examplesRemaining.toInt();
      }
      final exampleLimit = map['exampleDailyLimit'];
      if (exampleLimit is num) _exampleDailyLimit = exampleLimit.toInt();
      final perWord = map['maxExamplesPerWord'];
      if (perWord is num) _maxExamplesPerWord = perWord.toInt();
      // 패롯으로 사 둔 몫(5차 532). examplesRemainingToday에는 이미 더해져
      // 있고, 이 값은 '하루 한도와 따로 가진 것'을 따로 보여 줄 때 쓴다.
      final credits = map['exampleCredits'];
      if (credits is num) _exampleCredits = credits.toInt();
      final assistCredits = map['assistCredits'];
      if (assistCredits is num) _assistCredits = assistCredits.toInt();
      debugPrint('[assist] ${data['mode']} ok, remaining=$_remainingToday');
      // 어느 부름이든 응답에 지금 숫자가 들어 있다. 받을 때마다 갱신하고
      // 알리면, 한 화면에서 쓴 뒤 다른 화면이 옛 숫자를 들고 있지 않다.
      _mark();
      notifyListeners();
      return map;
    } on FirebaseFunctionsException catch (e) {
      // 아래에서 코드별로 typed exception으로 바꿔 화면까지 전달한다.
      // 한도 초과처럼 예상되는 것도 섞여 있어 w로 남긴다.
      AppLogger.w('[assist] ${data['mode']} 실패: ${e.code} ${e.message}');
      switch (e.code) {
        case 'resource-exhausted':
          // 서버는 두 한도 모두 같은 코드로 돌려준다. 예문을 받으려던
          // 부름이었으면 예문 쪽을 0으로 적는다. 전에는 늘 뜻·발음
          // 횟수를 0으로 적어서, 예문을 다 쓴 사람의 '뜻·발음 채우기'가
          // 멀쩡한데도 꺼지고, 정작 예문 단추는 열린 채로 남았다(5차 517).
          if (wantsExamples) {
            // 서버가 거절했다는 것은 하루 몫도 사 둔 몫도 없다는 뜻이다.
            _examplesRemainingToday = 0;
            _exampleCredits = 0;
          } else {
            _remainingToday = 0;
            _assistCredits = 0;
          }
          notifyListeners();
          throw SentenceAssistQuotaExceeded(examples: wantsExamples);
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
  Future<SentenceComplete> complete({
    required String language,
    String text = '',
    String translation = '',
    String pronunciation = '',
    bool word = false,
  }) async {
    final map = await _call({
      'mode': 'complete',
      'language': language,
      'text': text,
      'translation': translation,
      'pronunciation': pronunciation,
      'word': word,
    });
    return SentenceComplete(
      text: map['text'] as String?,
      translation: map['translation'] as String?,
      pronunciation: map['pronunciation'] as String?,
    );
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
      pronunciation: map['pronunciation'] as String?,
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
