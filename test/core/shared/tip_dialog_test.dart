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
  testWidgets('이용 안내는 서버·Drive 저장이 생긴 지금에 맞는 백업 안내를 한다',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.text('로컬 클립은 백업해 두세요'), findsOneWidget);
    expect(find.textContaining('이 기기에만 저장돼요'), findsNothing);
    expect(find.textContaining('Google Drive'), findsOneWidget);
    // 실제 버튼 이름('옮기기')으로 방법을 알려 준다.
    expect(find.textContaining("'옮기기'"), findsOneWidget);
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
