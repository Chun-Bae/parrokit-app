import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parrokit/core/shared/widgets/app_bottom_sheet.dart';

void main() {
  setUp(() => openAppSheetCount.value = 0);

  testWidgets('시트가 떠 있는 동안에만 탭 바 숨김 신호가 켜진다', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        ctx = context;
        return const Scaffold(body: SizedBox());
      }),
    ));

    expect(openAppSheetCount.value, 0);

    final future = showAppSheet<void>(
      context: ctx,
      builder: (_) => const SizedBox(height: 100, child: Text('시트')),
    );
    await tester.pumpAndSettle();
    expect(openAppSheetCount.value, 1);
    expect(find.text('시트'), findsOneWidget);

    Navigator.of(ctx).pop();
    await tester.pumpAndSettle();
    await future;
    expect(openAppSheetCount.value, 0);
  });

  testWidgets('공통 시트를 안 쓰는 곳도 withNavBarHiddenForSheet로 같이 숨긴다',
      (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        ctx = context;
        return const Scaffold(body: SizedBox());
      }),
    ));

    final future = withNavBarHiddenForSheet<void>(
      () => showModalBottomSheet<void>(
        context: ctx,
        builder: (_) => const SizedBox(height: 100, child: Text('직접 시트')),
      ),
    );
    await tester.pumpAndSettle();
    expect(openAppSheetCount.value, 1);

    Navigator.of(ctx).pop();
    await tester.pumpAndSettle();
    await future;
    expect(openAppSheetCount.value, 0);
  });

  testWidgets('시트 두 개가 겹쳐 떠도 다 닫혀야 탭 바가 돌아온다', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        ctx = context;
        return const Scaffold(body: SizedBox());
      }),
    ));

    final first = showAppSheet<void>(
        context: ctx, builder: (_) => const SizedBox(height: 80));
    await tester.pumpAndSettle();
    final second = showAppSheet<void>(
        context: ctx, builder: (_) => const SizedBox(height: 80));
    await tester.pumpAndSettle();
    expect(openAppSheetCount.value, 2);

    Navigator.of(ctx).pop();
    await tester.pumpAndSettle();
    await second;
    expect(openAppSheetCount.value, 1);

    Navigator.of(ctx).pop();
    await tester.pumpAndSettle();
    await first;
    expect(openAppSheetCount.value, 0);
  });
}
