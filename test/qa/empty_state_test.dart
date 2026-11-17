// 빈 화면이 바른 말을 쓰고, 무엇을 하면 되는지 알려 준다(5차 441).
//
// 홈의 빈 카드는 조사를 '이'로 고정해 놓아 받침 없는 말이 오면
// '아직 등록된 폴더이 없어요'가 됐다. '등록'도 앱이 쓰지 않는 말이다.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/utils/korean_josa.dart';
import 'package:parrokit/features/home/dashboard/presentation/widgets/empty_card.dart';

Iterable<File> _dartFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

void main() {
  test('조사를 받침에 맞춘다', () {
    expect(iGa('폴더'), '폴더가');
    expect(iGa('자막'), '자막이');
  });

  testWidgets('빈 카드가 받침에 맞는 조사를 쓴다', (tester) async {
    for (final noun in ['폴더', '자막']) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EmptyCard(
            noun: noun,
            subtle: Colors.grey,
            textSecondary: Colors.grey,
          ),
        ),
      ));
      expect(find.text('아직 ${iGa(noun)} 없어요'), findsOneWidget,
          reason: noun);
    }
  });

  test("빈 화면에 '등록'이라는 말이 없다", () {
    final offenders = <String>[];
    for (final file in _dartFiles()) {
      for (final line in file
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))) {
        if (line.contains("'") &&
            line.contains('아직') &&
            line.contains('등록')) {
          offenders.add('${file.path}: ${line.trim()}');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('폴더·클립 빈 화면이 무엇을 하면 되는지 적는다', () {
    final folder = File(
            'lib/features/collection/library/presentation/widgets/folder_grid.dart')
        .readAsStringSync();
    expect(folder, contains("description: '위 새 폴더로 만들 수 있어요.'"));

    final clips = File(
            'lib/features/collection/library/presentation/widgets/clip_list_view.dart')
        .readAsStringSync();
    expect(clips, contains('description:'));
  });
}
