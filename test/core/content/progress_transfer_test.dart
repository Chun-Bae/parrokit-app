// 학습 진도를 백업에 담고 되돌리기(5차 566).
//
// 백업 zip은 Documents만 훑는데 친밀도·XP·복습 진도는 모두
// SharedPreferences에 있다. 기기를 바꿔 복원하면 문장은 돌아오고
// 익힌 기록은 처음부터였다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/progress_transfer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('담을 칸 고르기', () {
    test('진도는 담는다', () {
      expect(isProgressKey('parrokit.sentence_activity.v1.me'), isTrue);
      expect(isProgressKey('parrokit.parrot.xp.v2.me'), isTrue);
      expect(isProgressKey('parrokit.word_reviews.v1.me'), isTrue);
      expect(isProgressKey('parrokit.practice_reward.ledger.v1.me'), isTrue);
    });

    // 새 기기에서 끈 알림이 복원으로 되살아나면 안 된다.
    test('기기 설정과 계정에 매인 값은 담지 않는다', () {
      expect(isProgressKey('parrokit.practice_reminder.enabled.v1'), isFalse);
      expect(isProgressKey('parrokit.speaking.gap_seconds.v1.me'), isFalse);
      expect(isProgressKey('parrokit.local_only_notice.dismissed_on.v1'),
          isFalse);
      expect(isProgressKey('google_drive_folder_id_someone@example.com_root'),
          isFalse);
      expect(isProgressKey('nativePlayer'), isFalse);
    });
  });

  group('종류를 지킨다', () {
    test('int와 double이 섞이지 않는다', () {
      expect(decodeProgressValue(encodeProgressValue(3)), 3);
      expect(decodeProgressValue(encodeProgressValue(3.0)), 3.0);
      expect(decodeProgressValue(encodeProgressValue(3)), isA<int>());
      expect(decodeProgressValue(encodeProgressValue(3.0)), isA<double>());
    });

    test('글·참거짓·글 목록도 그대로다', () {
      expect(decodeProgressValue(encodeProgressValue('가')), '가');
      expect(decodeProgressValue(encodeProgressValue(true)), isTrue);
      expect(decodeProgressValue(encodeProgressValue(['가', '나'])),
          ['가', '나']);
    });

    test('모르는 종류는 담지 않는다', () {
      expect(encodeProgressValue(const {'a': 1}), isNull);
      expect(decodeProgressValue('그냥 글'), isNull);
      expect(decodeProgressValue({'t': 'int', 'v': '셋'}), isNull);
    });
  });

  group('내보내고 되돌리기', () {
    test('진도만 담고 설정은 두고 간다', () async {
      SharedPreferences.setMockInitialValues({
        'parrokit.sentence_activity.v1.me': '{"s1":{"practiceCount":3}}',
        'parrokit.parrot.xp.v2.me': 42,
        'parrokit.practice_reminder.enabled.v1': true,
        'nativePlayer': true,
      });

      final raw = (await exportProgress())!;

      expect(raw, contains('parrokit.sentence_activity.v1.me'));
      expect(raw, contains('parrokit.parrot.xp.v2.me'));
      expect(raw, isNot(contains('practice_reminder')));
      expect(raw, isNot(contains('nativePlayer')));
    });

    test('빈 기기에서는 담을 것이 없다', () async {
      expect(await exportProgress(), isNull);
    });

    test('되돌리면 그 값이 그대로 들어온다', () async {
      SharedPreferences.setMockInitialValues({
        'parrokit.sentence_activity.v1.me': '{"s1":{"practiceCount":3}}',
        'parrokit.parrot.xp.v2.me': 42,
      });
      final raw = (await exportProgress())!;

      // 기기를 바꾼 셈 친다.
      SharedPreferences.setMockInitialValues({});
      expect(await importProgress(raw), 2);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('parrokit.parrot.xp.v2.me'), 42);
      expect(prefs.getString('parrokit.sentence_activity.v1.me'),
          '{"s1":{"practiceCount":3}}');
    });

    // 복원은 되돌리는 일이지 지우는 일이 아니다.
    test('백업에 없는 칸은 지우지 않는다', () async {
      SharedPreferences.setMockInitialValues({
        'parrokit.parrot.xp.v2.me': 42,
      });
      final raw = (await exportProgress())!;

      SharedPreferences.setMockInitialValues({
        'parrokit.sentence_activity.v1.me': '{"s9":{}}',
        'parrokit.practice_reminder.enabled.v1': false,
      });
      await importProgress(raw);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('parrokit.sentence_activity.v1.me'), '{"s9":{}}');
      expect(prefs.getBool('parrokit.practice_reminder.enabled.v1'), isFalse);
      expect(prefs.getInt('parrokit.parrot.xp.v2.me'), 42);
    });

    test('담을 수 없는 칸이 섞여 와도 던지지 않는다', () async {
      expect(await importProgress('{"version":1,"values":{'
          '"parrokit.parrot.xp.v2.me":{"t":"int","v":7},'
          '"nativePlayer":{"t":"bool","v":true},'
          '"parrokit.parrot.xp_day.v1.me":"깨진 값"}}'), 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('parrokit.parrot.xp.v2.me'), 7);
      expect(prefs.getBool('nativePlayer'), isNull);
    });

    test('글이 깨져 있으면 0이고 던지지 않는다', () async {
      expect(await importProgress('{'), 0);
      expect(await importProgress('[]'), 0);
    });
  });

  group('갈래를 가려 담는다', () {
    test('문장만 고르면 단어 복습 진도는 빠진다', () async {
      SharedPreferences.setMockInitialValues({
        'parrokit.parrot.xp.v2.me': 42,
        'parrokit.word_reviews.v1.me': '{"w1":{}}',
      });

      final raw = (await exportProgress(words: false))!;

      expect(raw, contains('parrokit.parrot.xp.v2.me'));
      expect(raw, isNot(contains('word_reviews')));
    });

    test('단어만 고르면 친밀도는 빠진다', () async {
      SharedPreferences.setMockInitialValues({
        'parrokit.sentence_activity.v1.me': '{"s1":{}}',
        'parrokit.word_reviews.v1.me': '{"w1":{}}',
      });

      final raw = (await exportProgress(sentences: false))!;

      expect(raw, contains('word_reviews'));
      expect(raw, isNot(contains('sentence_activity')));
    });

    test('되돌릴 때도 고른 갈래만 적는다', () async {
      SharedPreferences.setMockInitialValues({
        'parrokit.parrot.xp.v2.me': 42,
        'parrokit.word_reviews.v1.me': '{"w1":{}}',
      });
      final raw = (await exportProgress())!;

      SharedPreferences.setMockInitialValues({});
      expect(await importProgress(raw, words: false), 1);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('parrokit.parrot.xp.v2.me'), 42);
      expect(prefs.getString('parrokit.word_reviews.v1.me'), isNull);
    });
  });

  // 고르기 시트가 '담지 않아요'라고 적어 두면 담아도 아무도 모른다.
  test('고르기 시트가 진도를 담는다고 적는다', () {
    final sheet = File(
      'lib/features/settings/more/presentation/widgets/'
      'backup_parts_sheet.dart',
    ).readAsStringSync();
    expect(sheet, isNot(contains('연습 기록은 담지 않아요')));
    expect(sheet, isNot(contains('복습 진도는 담지 않아요')));
    expect(sheet, contains('친밀도와 연습 기록'));
    expect(sheet, contains('복습 진도'));
  });

  // 백업·복원 양쪽에 붙어 있어야 한 쪽만 고쳐 놓고 끝나지 않는다.
  test('백업과 복원이 모두 진도 파일을 다룬다', () {
    final source = File(
      'lib/core/infrastructure/services/backup_service.dart',
    ).readAsStringSync();
    expect(source, contains('exportProgress('));
    expect(source, contains('importProgress('));
    expect(source, contains('progressDataFileName'));
  });
}
