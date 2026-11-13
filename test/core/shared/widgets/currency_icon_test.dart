import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/widgets/currency_icon.dart';

void main() {
  testWidgets('패롯·크래커 그림은 등록된 에셋을 쓰고 이름을 읽어 준다', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Column(children: [
          CurrencyIcon(Currency.parrot),
          CurrencyAmount(Currency.cracker, 30, prefix: '답하면 '),
        ]),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(SvgPicture), findsNWidgets(2));
    expect(find.bySemanticsLabel('패롯'), findsOneWidget);
    expect(find.bySemanticsLabel('크래커'), findsOneWidget);
    expect(find.text('답하면 '), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
  });
}
