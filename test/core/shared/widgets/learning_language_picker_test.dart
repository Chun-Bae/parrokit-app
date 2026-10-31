import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/widgets/learning_language_picker.dart';

void main() {
  testWidgets('언어 선택 시트에서 검색하고 언어를 변경한다', (tester) async {
    var selected = '영어';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => LearningLanguagePicker(
              value: selected,
              onChanged: (value) => setState(() => selected = value),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('영어'));
    await tester.pumpAndSettle();
    expect(find.text('언어 검색'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '中文');
    await tester.pump();
    expect(find.text('중국어'), findsOneWidget);

    await tester.tap(find.text('중국어'));
    await tester.pumpAndSettle();
    expect(selected, '중국어');
    expect(find.text('중국어'), findsOneWidget);
  });
}
