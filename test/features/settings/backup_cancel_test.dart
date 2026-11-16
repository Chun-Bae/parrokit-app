// 파일 고르기·저장을 그만두면 실패 화면이 뜨지 않는다(5차 362).
//
// 전에는 저장 창을 닫기만 해도 '안 됐어요 / 백업하지 못했어요'라는 빨간
// 화면이 떠서, 앱이 망가진 것처럼 보였다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/infrastructure/services/backup_cancelled.dart';
import 'package:parrokit/features/settings/more/presentation/widgets/backup_progress_dialog.dart';

Future<void> _pumpDialog(
  WidgetTester tester,
  Future<void> Function(Function(BackupProgress)) onStart,
) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: BackupProgressDialog(
        type: BackupDialogType.backup,
        onStart: onStart,
      ),
    ),
  ));
  await tester.pump();
  await tester.tap(find.text('백업 시작'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('그만두면 처음 단계로 돌아간다', (tester) async {
    await _pumpDialog(tester, (_) async => throw const BackupCancelled());
    expect(find.text('백업 시작'), findsOneWidget);
    expect(find.text('안 됐어요'), findsNothing);
    expect(find.text('백업하지 못했어요.'), findsNothing);
  });

  testWidgets('진짜 실패는 그대로 알린다', (tester) async {
    await _pumpDialog(
        tester, (_) async => throw Exception('파일을 저장하지 못했어요.'));
    expect(find.text('안 됐어요'), findsOneWidget);
    expect(find.text('백업하지 못했어요.'), findsOneWidget);
    expect(find.text('파일을 저장하지 못했어요.'), findsOneWidget);
  });

  testWidgets('잘 되면 다 됐어요', (tester) async {
    await _pumpDialog(tester, (_) async {});
    expect(find.text('다 됐어요'), findsOneWidget);
  });
}
