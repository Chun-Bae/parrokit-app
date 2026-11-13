import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/widgets/tip_dialog.dart';

void main() {
  testWidgets('이용 안내는 서버·Drive 저장이 생긴 지금에 맞는 백업 안내를 한다',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showTipDialog(context, force: true),
          child: const Text('열기'),
        ),
      ),
    ));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.text('로컬 클립은 백업해 두세요'), findsOneWidget);
    expect(find.textContaining('이 기기에만 저장돼요'), findsNothing);
    expect(find.textContaining('Google Drive'), findsOneWidget);
  });
}
