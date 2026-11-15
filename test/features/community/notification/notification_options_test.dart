// 알림 메뉴: 지금 할 수 없는 일은 흐리게 보이고 눌러도 아무 일이 없다(5차).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/community/shared/presentation/widgets/community_options_sheet.dart';

void main() {
  Future<void> openSheet(
    WidgetTester tester,
    List<CommunityOptionAction> actions,
  ) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () =>
                  showCommunityOptionsSheet(context: context, actions: actions),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('열기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('끈 줄은 눌러도 아무 일이 없다', (tester) async {
    var ran = 0;
    await openSheet(tester, [
      CommunityOptionAction(
        label: '모두 읽음',
        enabled: false,
        onTap: () async => ran++,
      ),
    ]);

    await tester.tap(find.text('모두 읽음'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(ran, 0, reason: '할 수 없는 일이면 돌지 않는다');
    expect(find.text('모두 읽음'), findsOneWidget, reason: '시트도 닫히지 않는다');
  });

  testWidgets('켠 줄은 눌리고 시트가 닫힌다', (tester) async {
    var ran = 0;
    await openSheet(tester, [
      CommunityOptionAction(label: '모두 읽음', onTap: () async => ran++),
    ]);

    await tester.tap(find.text('모두 읽음'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(ran, 1);
    expect(find.text('모두 읽음'), findsNothing);
  });

  testWidgets('끈 줄은 글자가 흐리다', (tester) async {
    await openSheet(tester, [
      CommunityOptionAction(label: '켬', onTap: () async {}),
      CommunityOptionAction(label: '끔', enabled: false, onTap: () async {}),
    ]);

    Color colorOf(String label) =>
        tester.widget<Text>(find.text(label)).style!.color!;

    expect(colorOf('끔').a, lessThan(colorOf('켬').a));
  });
}
