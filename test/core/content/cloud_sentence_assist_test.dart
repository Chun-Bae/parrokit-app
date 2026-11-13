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
            .having((e) => e.reason, 'reason', '로그인 후 쓸 수 있어요')));
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
}
