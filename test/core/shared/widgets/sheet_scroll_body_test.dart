// 시트 가운데의 위 가장자리 흐림(5차 566).
//
// 머리 바로 아래에서 내용이 칼로 자른 듯 끊겨, 둥근 단추의 아랫단이
// 반쯤 남아 깨진 것처럼 보였다. 맨 위에서는 흐리지 않고, 구르기
// 시작하면 흐린다.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/widgets/sheet_scroll_body.dart';

final _key = GlobalKey<SheetScrollBodyState>();

Future<void> _pump(WidgetTester tester, ScrollController controller) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SizedBox(
        height: 200,
        child: SheetScrollBody(
          key: _key,
          controller: controller,
          child: const SizedBox(height: 1200, child: Text('내용')),
        ),
      ),
    ),
  ));
}

double _fade() => _key.currentState!.fadeAmount;

void main() {
  testWidgets('맨 위에서는 흐리지 않는다', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await _pump(tester, controller);

    expect(_fade(), 0);
  });

  testWidgets('구르면 위를 흐린다', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await _pump(tester, controller);

    controller.jumpTo(80);
    await tester.pump();

    expect(_fade(), 1);
  });

  testWidgets('다시 맨 위로 오면 흐림을 걷는다', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await _pump(tester, controller);

    controller.jumpTo(80);
    await tester.pump();
    controller.jumpTo(0);
    await tester.pump();

    expect(_fade(), 0);
  });

  // 흐림이 생기고 사라질 때 트리 깊이가 바뀌면 Scrollable이 다시
  // 만들어져 구르던 자리가 맨 위로 튄다.
  testWidgets('흐림이 생겨도 구르던 자리를 잃지 않는다', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await _pump(tester, controller);

    controller.jumpTo(300);
    await tester.pump();

    expect(controller.offset, 300);
    expect(find.byType(ShaderMask), findsOneWidget);
  });

  testWidgets('밖에서 받은 스크롤은 밖이 버린다', (tester) async {
    final controller = ScrollController();
    await _pump(tester, controller);
    await tester.pumpWidget(const SizedBox.shrink());

    // 이미 버려졌다면 여기서 StateError가 난다.
    expect(controller.hasClients, isFalse);
    controller.dispose();
  });

  // 세 시트가 같은 꼴을 쓴다. 한 곳만 고치면 다른 데서 또 잘려 보인다.
  test('단어·문장 시트가 모두 이것을 쓴다', () {
    for (final path in [
      'lib/features/collection/shell/presentation/widgets/'
          'word_collection_preview.dart',
      'lib/features/collection/shell/presentation/widgets/word_edit_sheet.dart',
      'lib/features/home/dashboard/presentation/add_sentence_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('SheetScrollBody('), reason: path);
    }
  });
}
