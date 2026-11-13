import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/theme/app_theme.dart';
import 'package:parrokit/features/collection/library/presentation/folder_picker_sheet.dart';

Future<String?> openPicker(WidgetTester tester, List<String> names,
    {String? selected}) async {
  String? result;
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async => result = await showFolderPicker(context,
              existingNames: names, selected: selected),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('폴더를 트리로 보여주고 눌러서 고르면 경로를 돌려준다', (tester) async {
    String? picked;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => picked = await showFolderPicker(context,
                existingNames: ['여행', '여행/일본', '일상회화']),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('여행'), findsOneWidget);
    expect(find.text('일본'), findsOneWidget);
    expect(find.text('여행/일본'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('pick-folder-여행/일본')));
    await tester.pumpAndSettle();
    expect(picked, '여행/일본');
  });

  testWidgets("폴더 안에 새 폴더를 만들면 '/'를 치지 않아도 경로가 된다", (tester) async {
    String? picked;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => picked =
                await showFolderPicker(context, existingNames: ['여행']),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('new-folder-in-여행')));
    await tester.pumpAndSettle();
    expect(find.text("'여행' 안에 새 폴더"), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('new-folder-name')), '일/본');
    await tester.pump();
    expect(find.text("'/'는 쓸 수 없어요"), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('new-folder-name')), '일본');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('confirm-new-folder')));
    await tester.pumpAndSettle();
    expect(picked, '여행/일본');
  });

  testWidgets('폴더가 없으면 안내하고 맨 위에 새 폴더를 만들 수 있다', (tester) async {
    await openPicker(tester, []);
    expect(find.textContaining('아직 폴더가 없어요'), findsOneWidget);
    expect(find.byKey(const ValueKey('new-root-folder')), findsOneWidget);
  });
}
