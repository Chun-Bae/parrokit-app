// 백업·불러오기에서 고르는 시트(5차 345·349).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/study_data_transfer.dart';
import 'package:parrokit/features/settings/more/presentation/widgets/backup_parts_sheet.dart';

Future<void> _pump(WidgetTester tester,
    {required bool restoring, BackupParts? initial}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: BackupPartsSheet(
        restoring: restoring,
        initial: initial ?? const BackupParts.all(),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('백업은 셋 다 켜진 채로 시작하고 끄면 빠진다', (tester) async {
    await _pump(tester, restoring: false);
    expect(find.text('무엇을 백업할까요?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('backup-part-words')));
    await tester.pump();
    // 하나를 꺼도 나머지는 그대로 담는다.
    expect(
        tester
            .widget<CheckboxListTile>(
                find.byKey(const ValueKey('backup-part-words')))
            .value,
        isFalse);
    expect(
        tester
            .widget<CheckboxListTile>(
                find.byKey(const ValueKey('backup-part-clips')))
            .value,
        isTrue);
  });

  testWidgets('막힌 까닭을 빨강으로 적지 않는다(5차 503)', (tester) async {
    // 아직 안 고른 것은 잘못이 아니라 할 일이다. 같은 자리의 다른 화면
    // (새 클립 '영상을 먼저 골라 주세요.', 음성 만들기 '읽을 글을 적어
    // 주세요.')도 흐린 글씨를 쓴다(475의 규칙).
    await _pump(tester, restoring: false);
    for (final key in const [
      'backup-part-sentences',
      'backup-part-words',
      'backup-part-clips',
    ]) {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pump();
    }
    final reason = tester.widget<Text>(
        find.byKey(const ValueKey('backup-parts-blocked-reason')));
    final colors = Theme.of(
            tester.element(find.byKey(const ValueKey('backup-parts-confirm'))))
        .colorScheme;
    expect(reason.style?.color, colors.onSurfaceVariant);
    expect(reason.style?.color, isNot(colors.error));
  });

  test('시트와 백업을 시작하는 쪽이 같은 말을 쓴다(5차 503)', () {
    final service = File('lib/core/infrastructure/services/backup_service.dart')
        .readAsLinesSync()
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');
    expect(service, contains('throw Exception(backupNoPartsMessage)'));
    // 손으로 적은 옛말이 남아 있지 않다.
    expect(service.contains('백업할 것을 하나는 골라 주세요'), isFalse);
  });

  testWidgets('하나도 고르지 않으면 단추가 꺼지고 까닭을 적는다', (tester) async {
    await _pump(tester, restoring: false);
    for (final key in const [
      'backup-part-sentences',
      'backup-part-words',
      'backup-part-clips',
    ]) {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pump();
    }
    expect(find.text(backupNoPartsMessage), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const ValueKey('backup-parts-confirm')))
            .onPressed,
        isNull);
  });

  testWidgets('클립 화면에서 열면 클립만 켜져 있다', (tester) async {
    await _pump(tester,
        restoring: false,
        initial:
            const BackupParts(clips: true, sentences: false, words: false));
    expect(
        tester
            .widget<CheckboxListTile>(
                find.byKey(const ValueKey('backup-part-sentences')))
            .value,
        isFalse);
    expect(
        tester
            .widget<CheckboxListTile>(
                find.byKey(const ValueKey('backup-part-clips')))
            .value,
        isTrue);
  });

  // 여는 단추와 진행 창이 '불러오기'인데 이 시트만 '되돌리기'였다(5차 487).
  testWidgets('불러오기는 말이 다르고, 흐름과 같은 이름을 쓴다', (tester) async {
    await _pump(tester, restoring: true);
    expect(find.text('무엇을 불러올까요?'), findsOneWidget);
    expect(find.text('불러오기'), findsOneWidget);
    expect(find.text('무엇을 백업할까요?'), findsNothing);
    expect(find.text('되돌리기'), findsNothing);
  });

  test('클립 카드의 백업 단추도 고르는 시트를 거친다', () {
    final code = File(
            'lib/features/collection/library/presentation/clip_library_home.dart')
        .readAsStringSync()
        .replaceAll(RegExp(r'\s+'), ' ');
    expect(code, contains('showBackupPartsSheet('));
    expect(code, contains('clips: true, sentences: false, words: false'));
  });
}
