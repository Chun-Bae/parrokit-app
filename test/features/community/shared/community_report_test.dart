import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/data/models/user.dart';
import 'package:parrokit/features/community/shared/data/community_report_repository.dart';
import 'package:parrokit/features/community/shared/presentation/widgets/community_report_actions.dart';
import 'package:provider/provider.dart';

class _MockUserProvider extends Mock implements UserProvider {}

void main() {
  late FakeFirebaseFirestore firestore;
  late _MockUserProvider user;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    user = _MockUserProvider();
    when(user.currentUser).thenReturn(const AppUser(id: 'alice'));
  });

  Future<void> openAndReport(WidgetTester tester,
      {required String postId, String? commentId, String? pick}) async {
    await tester.pumpWidget(ChangeNotifierProvider<UserProvider>.value(
      value: user,
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => buildCommunityReportAction(
              context: context,
              postId: postId,
              commentId: commentId,
              targetAuthorId: 'bob',
              repository: CommunityReportRepository(firestore: firestore),
            ).onTap(),
            child: const Text('신고 누르기'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('신고 누르기'));
    await tester.pumpAndSettle();
    expect(find.text('신고 사유'), findsOneWidget);
    if (pick == null) {
      await tester.tap(find.text('취소'));
    } else {
      await tester.tap(find.byKey(ValueKey('report-reason-$pick')));
    }
    await tester.pumpAndSettle();
  }

  Future<List<Map<String, dynamic>>> reports() async =>
      (await firestore.collection('reports').get())
          .docs
          .map((d) => d.data())
          .toList();

  testWidgets('사유를 고르면 신고가 남는다(글)', (tester) async {
    await openAndReport(tester, postId: 'p1', pick: 'spam');
    final saved = await reports();
    expect(saved, hasLength(1));
    expect(saved.single['reporterId'], 'alice');
    expect(saved.single['targetType'], 'post');
    expect(saved.single['postId'], 'p1');
    expect(saved.single.containsKey('commentId'), isFalse);
    expect(saved.single['targetAuthorId'], 'bob');
    expect(saved.single['reason'], 'spam');
  });

  testWidgets('댓글 신고는 commentId와 함께 남는다', (tester) async {
    await openAndReport(tester, postId: 'p1', commentId: 'c9', pick: 'abuse');
    final saved = (await reports()).single;
    expect(saved['targetType'], 'comment');
    expect(saved['commentId'], 'c9');
    expect(saved['reason'], 'abuse');
  });

  testWidgets('취소하면 아무것도 남지 않는다', (tester) async {
    await openAndReport(tester, postId: 'p1');
    expect(await reports(), isEmpty);
  });

  testWidgets('개발 빌드 가짜 글은 서버에 쓰지 않는다', (tester) async {
    await openAndReport(tester, postId: 'debug-fake-board-1', pick: 'other');
    expect(await reports(), isEmpty);
  });
}
