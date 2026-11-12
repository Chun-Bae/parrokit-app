import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/theme/app_theme.dart';
import 'package:parrokit/core/shared/widgets/app_segmented_tabs.dart';

void main() {
  testWidgets('좁은 화면에서 다섯 칸이어도 글자가 두 줄로 꺾이지 않는다', (tester) async {
    // 375pt 폰에서 좌우 여백을 뺀 너비.
    tester.view.physicalSize = const Size(375, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const labels = ['전체', '채택 완료', '답변 대기중', '화제의 질문', '오래된 질문'];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppSegmentedTabs(
              selectedIndex: 2,
              onChanged: (_) {},
              segments: [for (final l in labels) AppSegment(label: l)],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final oneLine = tester.getSize(find.text('전체')).height;
    for (final label in labels) {
      // 두 줄이 되면 높이가 한 줄짜리의 두 배 가까이 된다.
      expect(tester.getSize(find.text(label)).height, oneLine,
          reason: '$label 이 한 줄이어야 한다');
    }
  });
}
