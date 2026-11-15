// Drive에 남은 클립을 알리고 기기로 가져오게 하는 안내.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/features/collection/library/presentation/widgets/drive_migration_notice.dart';

Widget _wrap(Widget child) {
  final cs = ColorScheme.fromSeed(seedColor: Colors.blue);
  return MaterialApp(
    theme: ThemeData(
      colorScheme: cs,
      textTheme: appTextTheme(cs, isDark: false),
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('남은 클립이 없으면 아무것도 그리지 않는다', (tester) async {
    await tester.pumpWidget(_wrap(
      DriveMigrationNotice(clipCount: 0, onImport: () {}),
    ));
    expect(find.byKey(const ValueKey('drive-migration-notice')), findsNothing);
  });

  testWidgets('몇 개가 남았는지와 지워진다는 것을 적는다', (tester) async {
    await tester.pumpWidget(_wrap(
      DriveMigrationNotice(clipCount: 3, onImport: () {}),
    ));

    expect(find.text(driveNoticeTitle), findsOneWidget);
    expect(find.textContaining('클립 3개'), findsOneWidget);
    expect(find.textContaining('Drive에 있던 파일은 지워져요'), findsOneWidget);
    expect(find.text(driveNoticeActionLabel), findsOneWidget);
  });

  testWidgets('가져오기를 누르면 알려 준다', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_wrap(
      DriveMigrationNotice(clipCount: 1, onImport: () => taps++),
    ));
    await tester.tap(find.byKey(const ValueKey('drive-migration-import')));
    expect(taps, 1);
  });

  testWidgets('가져오는 동안에는 다시 누를 수 없다', (tester) async {
    await tester.pumpWidget(_wrap(
      DriveMigrationNotice(clipCount: 2, onImport: () {}, busy: true),
    ));
    final button = tester.widget<ButtonStyleButton>(
        find.byKey(const ValueKey('drive-migration-import')));
    expect(button.onPressed, isNull);
  });

  test('확인 창도 지워진다는 것을 먼저 말한다', () {
    expect(driveNoticeConfirmBody(2), contains('클립 2개'));
    expect(driveNoticeConfirmBody(2), contains('지워져요'));
    for (final text in [
      driveNoticeTitle,
      driveNoticeBody(1),
      driveNoticeDoneToast,
      driveNoticeFailToast,
    ]) {
      expect(text, isNot(contains('습니다')), reason: text);
    }
  });
}
