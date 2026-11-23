// 백업·불러오기 안내가 실제로 하는 일과 맞는지(5차 345에서 갱신).
//
// 이제 앞 시트에서 문장·단어·클립을 골라 담고 되돌린다. 클립과 자막은
// paro.db와 영상 파일이라 되돌리면 지금 것이 모두 바뀌고, 문장과 단어는
// 없는 것만 더한다. 안내가 그 차이를 말해야 한다.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/study_data_transfer.dart';
import 'package:parrokit/features/settings/more/presentation/widgets/backup_progress_dialog.dart';

Future<String> _descriptionOf(
    WidgetTester tester, BackupDialogType type) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: BackupProgressDialog(
        type: type,
        onStart: (_) async {},
      ),
    ),
  ));
  await tester.pump();
  final texts = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .where((t) => t.contains('클립'));
  return texts.join('\n');
}

void main() {
  testWidgets('백업 안내는 고른 것을 담는다고 말하고, 클립이 큰 것도 알린다', (tester) async {
    final text = await _descriptionOf(tester, BackupDialogType.backup);
    expect(text, contains('고른 것'));
    expect(text, contains('클립과 자막'));
    // 예전 글: '지금 앱에 있는 것(클립, 자막 등)', '문장과 단어는 묶지 않아요'
    expect(text.contains('지금 앱에 있는 것'), isFalse);
    expect(text.contains('문장과 단어는 따로 저장돼서 묶지 않아요'), isFalse);
  });

  testWidgets('불러오기 안내는 문장·단어는 더하고 클립은 바뀐다고 말한다', (tester) async {
    final text = await _descriptionOf(tester, BackupDialogType.restore);
    expect(text, contains('없는 것만 더해요'));
    expect(text, contains('모두 지워지고'));
    expect(text.contains('문장과 단어는 그대로예요'), isFalse);
  });

  // 고른 것과 상관없이 늘 같은 글이 떴다(5차 521). 단어만 담는데도 '클립과
  // 자막은 영상 파일까지 담아서 파일이 커요'가 뜨고, 문장만 불러오는 사람도
  // '지금 기기의 클립과 자막은 모두 지워지고'를 읽었다.
  test('고르지 않은 것은 안내에 적지 않는다', () {
    const words = BackupParts(clips: false, sentences: false, words: true);
    final backup = backupDialogDescription(
        type: BackupDialogType.backup, parts: words);
    expect(backup, contains('고른 것'));
    expect(backup.contains('클립'), isFalse);

    final restore = backupDialogDescription(
        type: BackupDialogType.restore, parts: words);
    expect(restore, contains('없는 것만 더해요'));
    expect(restore.contains('클립'), isFalse);
    expect(restore.contains('다시 시작'), isFalse);
  });

  test('클립만 불러오면 문장·단어 이야기를 하지 않는다', () {
    const clips = BackupParts(clips: true, sentences: false, words: false);
    final restore = backupDialogDescription(
        type: BackupDialogType.restore, parts: clips);
    expect(restore, contains('모두 지워지고'));
    expect(restore.contains('없는 것만 더해요'), isFalse);

    final backup = backupDialogDescription(
        type: BackupDialogType.backup, parts: clips);
    expect(backup, contains('파일이 커요'));
  });

  // 한 흐름을 두 이름으로 부르던 것(5차 487). 여는 단추와 진행 창은
  // '불러오기'인데 고르기 시트만 '되돌리기'였고, 끝난 뒤 안내는
  // '되돌렸어요'였다.
  test('되돌리는 쪽은 어디서나 불러오기라 부른다', () {
    const paths = [
      'lib/features/settings/more/presentation/widgets/backup_parts_sheet.dart',
      'lib/features/settings/more/presentation/widgets/backup_progress_dialog.dart',
      'lib/core/content/study_data_transfer.dart',
    ];
    for (final path in paths) {
      final code = File(path)
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      for (final word in ['되돌릴까요', '되돌리기', '되돌려요', '되돌렸어요', '되돌린 뒤']) {
        expect(code.contains(word), isFalse, reason: '$path: $word');
      }
    }
  });

  test('문장·단어와 진도는 각자 한 곳을 거쳐 담긴다', () {
    // 설정(SharedPreferences)을 통째로 담지 않는다. 담는 것은
    // study_data_transfer가 만든 글과 progress_transfer가 고른 진도뿐이고,
    // 예전 백업에는 두 파일이 없다.
    final code = File('lib/core/infrastructure/services/backup_service.dart')
        .readAsStringSync();
    expect(code.contains('SharedPreferences'), isFalse,
        reason: '설정까지 담게 되면 안내도 함께 고쳐야 한다');
    expect(code, contains('studyDataFileName'));
    expect(code, contains('progressDataFileName'));
    expect(code, contains('BackupParts.fromManifest'));
  });

  // 문장·단어는 더하지만 진도는 덮어쓴다. 한 줄로 뭉뚱그리면 오늘 쌓은
  // 기록이 백업 때로 되돌아간 것을 뒤늦게 알게 된다(5차 566).
  group('불러오기가 진도를 덮어쓴다고 알린다', () {
    String restoreText(BackupParts parts) => backupDialogDescription(
          type: BackupDialogType.restore,
          parts: parts,
        );

    test('문장과 단어를 다 고르면 둘 다 적는다', () {
      final text = restoreText(
          const BackupParts(sentences: true, words: true, clips: false));
      expect(text, contains('친밀도와 연습 기록'));
      expect(text, contains('복습 진도'));
      expect(text, contains('그 뒤에 쌓은 것은 사라져요'));
    });

    test('문장만 고르면 복습 진도는 말하지 않는다', () {
      final text = restoreText(
          const BackupParts(sentences: true, words: false, clips: false));
      expect(text, contains('친밀도와 연습 기록'));
      expect(text, isNot(contains('복습 진도')));
    });

    test('단어만 고르면 친밀도는 말하지 않는다', () {
      final text = restoreText(
          const BackupParts(sentences: false, words: true, clips: false));
      expect(text, contains('복습 진도'));
      expect(text, isNot(contains('친밀도')));
    });

    // '복습 진도은(는)'처럼 적히면 앱의 다른 글과 어긋난다.
    // 기기에서 '복습 진도친밀도와 연습 기록, 복습 진도는'처럼 두 번 적혔다.
    test('말을 두 번 적지 않는다', () {
      final text = restoreText(
          const BackupParts(sentences: true, words: true, clips: false));
      expect('복습 진도'.allMatches(text).length, 1);
      expect('친밀도'.allMatches(text).length, 1);
    });

    test('조사를 끝 글자에 맞춘다', () {
      expect(
          restoreText(
              const BackupParts(sentences: true, words: true, clips: false)),
          contains('복습 진도는 백업 때의 것으로'));
      expect(
          restoreText(
              const BackupParts(sentences: true, words: false, clips: false)),
          contains('연습 기록은 백업 때의 것으로'));
    });

    test('클립만 고르면 진도 이야기는 없다', () {
      final text = restoreText(
          const BackupParts(sentences: false, words: false, clips: true));
      expect(text, isNot(contains('사라져요')));
    });

    test('백업하는 쪽에는 이 경고가 없다', () {
      final text = backupDialogDescription(
        type: BackupDialogType.backup,
        parts: const BackupParts(sentences: true, words: true, clips: true),
      );
      expect(text, isNot(contains('사라져요')));
    });
  });
}
