import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/cloud_sentence_assist.dart';
import 'package:parrokit/core/content/sentence_assist.dart';

/// 서버를 부르지 않고 응답을 정해 두는 가짜 함수.
class _FakeFunctions extends Fake implements FirebaseFunctions {
  _FakeFunctions(this.respond);

  final Object? Function(Map<String, Object?> data) respond;
  final calls = <Map<String, Object?>>[];
  final names = <String>[];

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    names.add(name);
    return _FakeCallable(this);
  }
}

class _FakeCallable extends Fake implements HttpsCallable {
  _FakeCallable(this.owner);

  final _FakeFunctions owner;

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    final data = Map<String, Object?>.from(parameters as Map);
    owner.calls.add(data);
    return _FakeResult<T>(owner.respond(data) as T);
  }
}

/// 서버가 영영 대답하지 않는 상황(5차 446).
class _SilentFunctions extends Fake implements FirebaseFunctions {
  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) =>
      _SilentCallable();
}

class _SilentCallable extends Fake implements HttpsCallable {
  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) =>
      Completer<HttpsCallableResult<T>>().future;
}

/// 첫 호출은 영영 대답하지 않고, 두 번째부터 답한다(5차 454).
class _SlowFirstFunctions extends Fake implements FirebaseFunctions {
  int calls = 0;

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) =>
      _SlowFirstCallable(this);
}

class _SlowFirstCallable extends Fake implements HttpsCallable {
  _SlowFirstCallable(this.owner);

  final _SlowFirstFunctions owner;

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) {
    owner.calls++;
    if (owner.calls == 1) return Completer<HttpsCallableResult<T>>().future;
    return Future.value(
        _FakeResult<T>({'remainingToday': 3, 'dailyLimit': 10} as T));
  }
}

class _FakeResult<T> extends Fake implements HttpsCallableResult<T> {
  _FakeResult(this.data);

  @override
  final T data;
}

FirebaseFunctionsException _error(String code) =>
    FirebaseFunctionsException(code: code, message: code);

void main() {
  test('번역 제안은 suggestSentenceInfo에 suggest로 묻고 남은 횟수를 기억한다', () async {
    final functions = _FakeFunctions((_) => {
          'translation': '안녕하세요',
          'pronunciation': '헬로',
          'remainingToday': 7,
          'dailyLimit': 10,
        });
    final assist = CloudSentenceAssist(functions: functions);
    expect(assist.remainingToday, isNull);

    final s = await assist.suggest(language: 'en', text: 'Hello');

    expect(functions.names.single, 'suggestSentenceInfo');
    expect(functions.calls.single,
        {'mode': 'suggest', 'language': 'en', 'text': 'Hello'});
    expect(s.translation, '안녕하세요');
    expect(s.pronunciation, '헬로');
    expect(assist.remainingToday, 7);
    expect(assist.dailyLimit, 10);
  });

  test('한글 발음 바꾸기는 transliterate로 묻고 text를 돌려준다', () async {
    final functions =
        _FakeFunctions((_) => {'text': 'konnichiwa', 'remainingToday': 3});
    final assist = CloudSentenceAssist(functions: functions);

    final text =
        await assist.transliterate(language: 'ja', hangul: '곤니치와');

    expect(functions.calls.single,
        {'mode': 'transliterate', 'language': 'ja', 'hangul': '곤니치와'});
    expect(text, 'konnichiwa');
    expect(assist.remainingToday, 3);
  });

  test('응답에 없는 값은 null로 둔다', () async {
    final assist = CloudSentenceAssist(functions: _FakeFunctions((_) => {}));
    final s = await assist.suggest(language: 'en', text: 'Hi');
    expect(s.translation, isNull);
    expect(s.pronunciation, isNull);
    expect(assist.remainingToday, isNull);
  });

  test('남은 횟수 조회는 status로 묻는다', () async {
    final functions =
        _FakeFunctions((_) => {'remainingToday': 5, 'dailyLimit': 10});
    final assist = CloudSentenceAssist(functions: functions);
    await assist.refreshUsage();
    expect(functions.calls.single, {'mode': 'status'});
    expect(assist.remainingToday, 5);
    expect(assist.dailyLimit, 10);
  });

  test('남은 횟수 조회가 실패해도 예외를 밖으로 내지 않는다', () async {
    final assist = CloudSentenceAssist(
        functions: _FakeFunctions((_) => throw _error('internal')));
    await assist.refreshUsage();
    expect(assist.remainingToday, isNull);
  });

  test('하루 한도를 넘으면 QuotaExceeded로 바꾸고 남은 횟수를 0으로', () async {
    final assist = CloudSentenceAssist(
        functions: _FakeFunctions((_) => throw _error('resource-exhausted')));
    await expectLater(assist.suggest(language: 'en', text: 'Hi'),
        throwsA(isA<SentenceAssistQuotaExceeded>()));
    expect(assist.remainingToday, 0);
  });

  test('로그인하지 않았으면 로그인 안내로 바꾼다', () async {
    final assist = CloudSentenceAssist(
        functions: _FakeFunctions((_) => throw _error('unauthenticated')));
    await expectLater(
        assist.transliterate(language: 'en', hangul: '헬로'),
        throwsA(isA<SentenceAssistUnavailable>()
            .having((e) => e.reason, 'reason', '로그인하면 쓸 수 있어요.')));
  });

  test('다른 서버 오류는 그대로 올린다', () async {
    final assist = CloudSentenceAssist(
        functions: _FakeFunctions((_) => throw _error('internal')));
    await expectLater(assist.suggest(language: 'en', text: 'Hi'),
        throwsA(isA<FirebaseFunctionsException>()));
  });

  test('응답이 맵이 아니면 실패로 본다', () async {
    final assist =
        CloudSentenceAssist(functions: _FakeFunctions((_) => 'oops'));
    await expectLater(assist.suggest(language: 'en', text: 'Hi'),
        throwsA(isA<StateError>()));
  });


  test('서버가 대답하지 않으면 횟수 조회를 접는다(5차 446)', () {
    // 전에는 기다림에 끝이 없어서 '횟수 확인 중…'이 영영 남았다.
    fakeAsync((async) {
      final assist = CloudSentenceAssist(functions: _SilentFunctions());
      var done = false;
      assist.refreshUsage().then((_) => done = true);

      async.elapse(const Duration(seconds: 7));
      expect(done, isFalse, reason: '아직 기다리는 중');

      // 한 번 접히면 조용히 한 번 더 묻는다(5차 454). 두 번째도 대답이
      // 없으면 그때 끝낸다.
      async.elapse(CloudSentenceAssist.usageTimeout);
      expect(done, isFalse, reason: '한 번 더 묻는 중');

      async.elapse(CloudSentenceAssist.usageTimeout);
      expect(done, isTrue, reason: '두 번 다 대답이 없으면 접는다');
      // 못 읽었으므로 숫자는 비어 있고, 화면은 '다시 확인'을 보여 준다.
      expect(assist.remainingToday, isNull);
    });
  });

  test('뜻 채우기도 끝없이 기다리지 않는다(5차 446)', () {
    fakeAsync((async) {
      final assist = CloudSentenceAssist(functions: _SilentFunctions());
      Object? thrown;
      assist
          .suggest(language: 'en', text: 'Hello')
          .catchError((Object e) => throw e)
          .onError((Object e, _) {
        thrown = e;
        return SentenceSuggestion();
      });

      async.elapse(CloudSentenceAssist.suggestTimeout + const Duration(seconds: 1));
      expect(thrown, isA<TimeoutException>());
    });
  });

  test('횟수 조회는 짧게, 글 만들기는 길게 기다린다', () {
    expect(CloudSentenceAssist.usageTimeout,
        lessThan(CloudSentenceAssist.suggestTimeout));
  });

  test('첫 조회가 접히면 조용히 한 번 더 묻는다(5차 454)', () {
    // 서버가 쉬다 깨는 첫 호출은 15초를 넘긴다. 전에는 사용자가
    // '탭해서 다시 확인'을 직접 눌러야 숫자가 떴다.
    fakeAsync((async) {
      final functions = _SlowFirstFunctions();
      final assist = CloudSentenceAssist(functions: functions);
      assist.refreshUsage();

      async.elapse(CloudSentenceAssist.usageTimeout + const Duration(seconds: 1));
      async.flushMicrotasks();

      expect(functions.calls, 2, reason: '한 번 더 물었다');
      expect(assist.remainingToday, 3);
    });
  });

  test('첫 조회가 오류로 끝나면 다시 묻지 않는다', () {
    // 시간이 모자라서가 아니라 서버가 거절한 것이면 또 물어도 같다.
    final functions = _FakeFunctions((_) => throw _error('internal'));
    final assist = CloudSentenceAssist(functions: functions);
    return assist.refreshUsage().then((_) {
      expect(functions.calls.length, 1);
    });
  });
}
