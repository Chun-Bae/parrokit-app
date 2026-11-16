// 백업·불러오기 안내가 실제로 하는 일과 맞는지(5차).
//
// 백업은 paro.db(클립·자막)와 영상 파일만 담는다. 문장과 단어는 로그인하면
// 서버에, 게스트면 기기 설정(SharedPreferences)에 따로 있어 백업에 들어가지도
// 않고 불러오기로 지워지지도 않는다. 예전 안내는 '지금 앱에 있는 것'이 모두
// 담기고 모두 지워지는 것처럼 읽혔다.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/settings/more/presentation/widgets/backup_progress_dialog.dart';

Future<String> _descriptionOf(WidgetTester tester, BackupDialogType type) async {
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
  testWidgets('백업 안내는 담는 것(클립·자막)과 안 담는 것(문장·단어)을 말한다',
      (tester) async {
    final text = await _descriptionOf(tester, BackupDialogType.backup);
    expect(text, contains('클립과 자막'));
    expect(text, contains('문장과 단어'));
    // 예전 글: '지금 앱에 있는 것(클립, 자막 등)'
    expect(text.contains('지금 앱에 있는 것'), isFalse);
  });

  testWidgets('불러오기 안내는 문장·단어가 그대로라는 것까지 말한다', (tester) async {
    final text = await _descriptionOf(tester, BackupDialogType.restore);
    expect(text, contains('클립과 자막은 모두 지워지고'));
    expect(text, contains('문장과 단어는 그대로'));
    expect(text.contains('지금 앱에 있는 것은 모두 지워지고'), isFalse);
  });

  test('백업이 담는 것은 데이터베이스와 영상 파일뿐이다', () {
    // 안내가 맞으려면 설정(SharedPreferences)은 백업에 들어가면 안 된다.
    final code =
        File('lib/core/infrastructure/services/backup_service.dart')
            .readAsStringSync();
    expect(code.contains('SharedPreferences'), isFalse,
        reason: '설정까지 담게 되면 안내도 함께 고쳐야 한다');
  });
}
