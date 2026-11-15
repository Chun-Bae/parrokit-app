// 저장 위치 고르기 시트. Google Drive 저장은 더 쓰지 않으므로 고를 수 없어야
// 한다(5차). 예전에 Drive에 올린 클립을 열면 '기기'가 골라진 채로 시작한다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/domain/collection_clip/data/constants/clip_storage_constants.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/features/collection/library/presentation/widgets/storage_transfer_sheet.dart';

Future<String?> _openSheet(
  WidgetTester tester, {
  String initialMode = ClipStorageConstants.storageModeLocal,
}) async {
  final cs = ColorScheme.fromSeed(seedColor: Colors.blue);
  String? result;
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(
      colorScheme: cs,
      textTheme: appTextTheme(cs, isDark: false),
    ),
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showStorageTransferSheet(
              context,
              title: '저장 위치 바꾸기',
              subtitle: '어디에 둘지 골라요.',
              initialMode: initialMode,
              serverLocked: true,
            );
          },
          child: const Text('열기'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('고를 수 있는 곳은 기기와 서버뿐이다', (tester) async {
    await _openSheet(tester);

    expect(find.text('기기'), findsOneWidget);
    expect(find.text('서버'), findsOneWidget);
    expect(find.text('Google Drive'), findsNothing);
  });

  testWidgets('Drive에 있던 클립은 기기가 골라진 채로 열린다', (tester) async {
    await _openSheet(tester,
        initialMode: ClipStorageConstants.storageModeGoogleDrive);

    // 고른 곳에는 체크 표시가 붙는다.
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    final checked = tester.widget<Icon>(find.byIcon(Icons.check_circle_rounded));
    expect(checked, isNotNull);
    expect(find.text('Google Drive'), findsNothing);
  });
}
