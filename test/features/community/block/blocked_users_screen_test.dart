import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:parrokit/core/infrastructure/services/firebase/firebase_user_service.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/data/models/user.dart';
import 'package:parrokit/features/community/block/data/repositories/block_repository_impl.dart';
import 'package:parrokit/features/community/block/presentation/blocked_users_screen.dart';
import 'package:parrokit/features/community/block/presentation/providers/block_provider.dart';
import 'package:provider/provider.dart';

class _MockUserProvider extends Mock implements UserProvider {}

void main() {
  testWidgets('차단 버튼은 닉네임을 넣어야 켜진다', (tester) async {
    final user = _MockUserProvider();
    when(user.currentUser).thenReturn(const AppUser(id: 'u1'));
    final block = BlockProvider(
      BlockRepositoryImpl(
          FirebaseUserService(firestore: FakeFirebaseFirestore())),
      user,
    );
    await tester.pumpWidget(ChangeNotifierProvider<BlockProvider>.value(
      value: block,
      child: const MaterialApp(home: BlockedUsersScreen()),
    ));
    await tester.pump();

    FilledButton button() =>
        tester.widget(find.byKey(const ValueKey('block-submit')));
    expect(button().onPressed, isNull);

    await tester.enterText(find.byType(TextField), '  ');
    await tester.pump();
    expect(button().onPressed, isNull, reason: '공백만은 빈 칸으로 본다');

    await tester.enterText(find.byType(TextField), '앵무');
    await tester.pump();
    expect(button().onPressed, isNotNull);
  });
}
