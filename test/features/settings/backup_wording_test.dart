// 백업·불러오기 안내가 실제로 하는 일과 맞는지(5차 345에서 갱신).
//
// 이제 앞 시트에서 문장·단어·클립을 골라 담고 되돌린다. 클립과 자막은
// paro.db와 영상 파일이라 되돌리면 지금 것이 모두 바뀌고, 문장과 단어는
// 없는 것만 더한다. 안내가 그 차이를 말해야 한다.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  test('문장·단어는 study.json 한 곳을 거쳐 담긴다', () {
    // 설정(SharedPreferences)을 통째로 담지 않는다. 담는 것은 study_data_transfer가
    // 만든 글 하나뿐이고, 예전 백업에는 그 파일이 없다.
    final code = File('lib/core/infrastructure/services/backup_service.dart')
        .readAsStringSync();
    expect(code.contains('SharedPreferences'), isFalse,
        reason: '설정까지 담게 되면 안내도 함께 고쳐야 한다');
    expect(code, contains('studyDataFileName'));
    expect(code, contains('BackupParts.fromManifest'));
  });
}
