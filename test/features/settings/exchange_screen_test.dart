import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:parrokit/core/shared/theme/app_theme.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/data/models/user.dart';
import 'package:parrokit/features/settings/more/presentation/exchange_screen.dart';

class _FakeUserProvider extends ChangeNotifier implements UserProvider {
  @override
  AppUser? get currentUser =>
      const AppUser(id: 'u1', parrots: 4, crackers: 44900);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(440, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ChangeNotifierProvider<UserProvider>.value(
    value: _FakeUserProvider(),
    child: MaterialApp(theme: AppTheme.light, home: const ExchangeScreen()),
  ));
  await tester.pump();
}

void main() {
  testWidgets('화면 제목·버튼과 같은 말(환전)을 쓴다', (tester) async {
    await _open(tester);
    // 여기만 '교환할'이라 '환전소'·'환전하기'와 어긋났다(5차).
    expect(find.textContaining('교환할'), findsNothing);
    expect(find.text('환전할 패롯 수량'), findsOneWidget);
  });

  testWidgets('수량을 넣기 전에는 무엇을 해야 하는지 알린다', (tester) async {
    await _open(tester);
    expect(find.byKey(const ValueKey('exchange-hint')), findsOneWidget);
    expect(find.byKey(const ValueKey('exchange-preview')), findsNothing);
  });

  testWidgets('수량을 넣으면 받을 양을 미리 보여준다', (tester) async {
    await _open(tester);
    await tester.enterText(find.byType(TextField), '2');
    await tester.pump();

    expect(find.byKey(const ValueKey('exchange-hint')), findsNothing);
    expect(find.text('받을 양: 2,000 크래커'), findsOneWidget);
  });

  testWidgets('가진 것보다 많으면 받을 양 대신 까닭을 보여준다', (tester) async {
    await _open(tester);
    await tester.enterText(find.byType(TextField), '10');
    await tester.pump();

    expect(find.text('가진 패롯보다 많아요 (보유 4)'), findsOneWidget);
  });
}
