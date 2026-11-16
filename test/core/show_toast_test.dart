// 토스트는 테마와 상관없이 떠야 한다(5차).
//
// margin은 floating일 때만 쓸 수 있는데 behavior를 테마에만 맡겨 두어서,
// 테마가 다른 화면에서는 SnackBar를 만들다 멈추고 아무것도 안 보였다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';

void main() {
  testWidgets('스낵바 테마가 없는 화면에서도 글이 보인다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      // 일부러 앱 테마를 주지 않는다(기본은 floating이 아니다).
      scaffoldMessengerKey: scaffoldMessengerKey,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showToast('테스트'),
            child: const Text('눌러'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('눌러'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.text('테스트'), findsOneWidget);
  });
}
