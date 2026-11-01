import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/sentence_activity_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('문장별 말하기, 연습, 루틴 상태를 함께 저장한다', () async {
    const accountId = 'tester';
    const sentenceId = 'basic-en-001';

    await SentenceActivityStore.incrementParrotSpeak(accountId, sentenceId);
    await SentenceActivityStore.incrementParrotSpeak(accountId, sentenceId);
    await SentenceActivityStore.incrementPractice(accountId, sentenceId);
    await SentenceActivityStore.incrementListen(accountId, sentenceId);
    await SentenceActivityStore.incrementListen(accountId, sentenceId);
    await SentenceActivityStore.incrementListen(accountId, sentenceId);
    await SentenceActivityStore.setRoutineEnabled(
      accountId,
      sentenceId,
      false,
    );

    final activity = await SentenceActivityStore.load(accountId, sentenceId);
    expect(activity.parrotSpeakCount, 2);
    expect(activity.practiceCount, 1);
    expect(activity.listenCount, 3);
    expect(activity.lastPracticedAt, isNotNull);
    expect(activity.routineEnabled, isFalse);
  });

  test('좋아요를 저장하고 취소할 수 있다', () async {
    expect((await SentenceActivityStore.load('a', 's1')).liked, isFalse);
    await SentenceActivityStore.setLiked('a', 's1', true);
    expect((await SentenceActivityStore.load('a', 's1')).liked, isTrue);
    await SentenceActivityStore.setLiked('a', 's1', false);
    expect((await SentenceActivityStore.load('a', 's1')).liked, isFalse);
  });
}
