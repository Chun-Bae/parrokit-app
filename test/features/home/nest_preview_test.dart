import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/home/dashboard/presentation/nest_preview.dart';

void main() {
  testWidgets('먹이를 주면 둥지가 채워지고 완성 후에는 더 주지 않는다', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: MediaQuery(
      data: MediaQueryData(disableAnimations: true),
      child: Scaffold(body: SingleChildScrollView(child: NestPreview())),
    )));
    expect(find.text('작은 새싹까지 먹이 1번'), findsOneWidget);
    for (var i = 0; i < 10; i++) {
      await tester.tap(find.text('학습 완료 · 먹이 주기'));
      await tester.pump();
    }
    expect(find.text('우리의 첫 번째 둥지가 완성됐어!'), findsOneWidget);
    expect(find.text('10 / 10'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
