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
    await SentenceActivityStore.setRoutineEnabled(
      accountId,
      sentenceId,
      false,
    );

    final activity = await SentenceActivityStore.load(accountId, sentenceId);
    expect(activity.parrotSpeakCount, 2);
    expect(activity.practiceCount, 1);
    expect(activity.routineEnabled, isFalse);
  });
}
