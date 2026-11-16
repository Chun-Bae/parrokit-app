// 시트 안에서 알리는 말은 시트 안에 보여야 한다(5차 369).
//
// 바텀시트는 화면 아래를 덮는다. 그 아래에 뜨는 SnackBar·토스트는 사용자
// 눈에 보이지 않는다(368에서 단어 시트로 확인했다).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/my_sentence_store.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/share_my_sentence_sheet.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/sentence_import_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MySentenceStore.cloud = null;
  });

  testWidgets('공유 시트는 알릴 말을 시트 맨 위에 적는다', (tester) async {
    await MySentenceStore.add('u1',
        language: '영어', text: 'Hello there!', translation: '안녕하세요!');
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ShareMySentenceSheet(accountId: 'u1', authorName: ''),
      ),
    ));
    await tester.pump();
    await tester.pump();

    final before =
        tester.widget<Text>(find.byKey(const ValueKey('share-sheet-note')));
    expect(before.data, contains('둘러보기에 올라가요'));

    // 공유할 수 없는 때(테스트에는 서버가 없다)에도 까닭이 시트 안에 뜬다.
    await tester.tap(find.text('공유'));
    await tester.pump();
    final note =
        tester.widget<Text>(find.byKey(const ValueKey('share-sheet-note')));
    expect(note.data, isNot(before.data));
    expect(note.data, contains('공유할 수 없어요'));
    expect(find.byType(SnackBar), findsNothing);
  });

  test('시트 안 안내는 토스트로 띄우지 않는다', () {
    for (final path in [
      'lib/features/collection/shell/presentation/widgets/share_my_sentence_sheet.dart',
      'lib/features/collection/shell/presentation/widgets/sentence_import_sheet.dart',
    ]) {
      final code = File(path).readAsStringSync();
      expect(code.contains('showToast('), isFalse, reason: path);
      expect(code.contains('showSnackBar('), isFalse, reason: path);
    }
  });

  test('가져오기 시트는 고른 것이 없을 때 쓸 안내를 들고 있다', () {
    final code = File(
            'lib/features/collection/shell/presentation/widgets/sentence_import_sheet.dart')
        .readAsStringSync();
    expect(code, contains("ValueKey('import-pick-hint')"));
    expect(importNeedsPickHint, '가져올 문장을 하나 이상 골라 주세요.');
  });
}
