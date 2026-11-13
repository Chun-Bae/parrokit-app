// 커뮤니티 글쓰기에서 쓰던 내용이 있으면 닫기 전에 묻는다(5차).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/shared/theme/app_theme.dart';
import 'package:parrokit/features/community/shared/presentation/widgets/draft_pop_scope.dart';

void main() {
  Future<void> openWriter(WidgetTester tester, {required bool hasDraft}) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (context) => DraftPopScope(
                hasDraft: hasDraft,
                child: Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.maybePop(context),
                    child: const Text('닫기'),
                  ),
                ),
              ),
            ),
          ),
          child: const Text('글쓰기'),
        ),
      ),
    ));
    await tester.tap(find.text('글쓰기'));
    await tester.pumpAndSettle();
  }

  testWidgets('쓴 것이 없으면 묻지 않고 닫힌다', (tester) async {
    await openWriter(tester, hasDraft: false);
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    expect(find.text('쓰던 내용을 버릴까요?'), findsNothing);
    expect(find.text('글쓰기'), findsOneWidget);
  });

  testWidgets('쓴 것이 있으면 묻고, 계속 쓰기면 남고 버리기면 닫힌다', (tester) async {
    await openWriter(tester, hasDraft: true);
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    expect(find.text('쓰던 내용을 버릴까요?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('draft-keep')));
    await tester.pumpAndSettle();
    expect(find.text('닫기'), findsOneWidget);

    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('draft-discard')));
    await tester.pumpAndSettle();
    expect(find.text('닫기'), findsNothing);
    expect(find.text('글쓰기'), findsOneWidget);
  });
}
