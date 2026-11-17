import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/widgets/tip_dialog.dart';
import 'package:parrokit/features/content-studio/captioning/data/constants/edit_strings.dart';

Widget app() => MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showTipDialog(context, force: true),
          child: const Text('열기'),
        ),
      ),
    );

void main() {
  testWidgets('이용 안내는 서버 저장이 생긴 지금에 맞는 백업 안내를 한다',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.text('기기에만 있는 클립은 백업해 두세요'), findsOneWidget);
    expect(find.textContaining('이 기기에만 저장돼요'), findsNothing);
    // Google Drive는 5차에 걷어냈다. 옮길 곳으로 더 말하지 않는다.
    expect(find.textContaining('Google Drive'), findsNothing);
    expect(find.textContaining('서버에'), findsOneWidget);
    // 실제 버튼 이름('옮기기')으로 방법을 알려 준다.
    expect(find.textContaining("'옮기기'"), findsOneWidget);
  });

  // 처음 켤 때 저절로 뜨는 창이 '결제 기능이 빠져 있어요'라고 했는데,
  // 지금은 패롯 충전과 광고 제거를 실제로 살 수 있다(5차 488).
  testWidgets('결제가 없다고 말하지 않는다', (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.text('베타 테스트 중'), findsNothing);
    expect(find.textContaining('결제 기능이 빠져'), findsNothing);
    expect(find.textContaining('베타'), findsNothing);
  });

  test('안내 글에 결제가 없다는 말이 남아 있지 않다', () {
    final code = File('lib/core/shared/widgets/tip_dialog.dart')
        .readAsLinesSync()
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    expect(code.contains('결제 기능이 빠져'), isFalse);
    expect(code.contains("title: '베타 테스트 중'"), isFalse);
  });

  testWidgets('없는 기능(노래 번역) 대신 실제로 있는 자동 자막을 안내한다',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    // 앱에 노래·가사 기능이 없는데 '노래 번역 품질'이라고 안내했다(5차).
    expect(find.text('노래 번역 품질'), findsNothing);
    expect(find.text('자동 자막 정확도'), findsOneWidget);
    // 자막 화면 안내와 같은 말로 맞춘다.
    expect(find.textContaining('소음이나 음악이 많은 영상'), findsOneWidget);
    expect(EditStrings.segmentsNotice, contains('소음이나 음악이 많은 영상'));
  });
}
