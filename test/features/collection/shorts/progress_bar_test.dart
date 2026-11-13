// 쇼츠 위 진행 줄은 영상 위에 그리므로 테마와 상관없이 흰색이어야 한다(5차).
// 예전엔 onSecondary를 써서 다크 테마에서 지금 칸이 어둡게 보였다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/collection/clip/shorts/presentation/widgets/progress_bar.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('$brightness 테마에서도 지금 칸은 흰색, 나머지는 옅은 흰색',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: const Scaffold(body: ProgressBar(index: 2, total: 5)),
      ));
      final colors = tester
          .widgetList<Container>(find.descendant(
              of: find.byType(ProgressBar), matching: find.byType(Container)))
          .map((c) => (c.decoration! as BoxDecoration).color)
          .toList();
      expect(colors, hasLength(5));
      expect(colors[2], Colors.white);
      for (final i in [0, 1, 3, 4]) {
        expect(colors[i], Colors.white.withValues(alpha: 0.35));
      }
    });
  }
}
