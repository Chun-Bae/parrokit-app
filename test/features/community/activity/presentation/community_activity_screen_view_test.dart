import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/features/community/activity/domain/entities/activity_page.dart';
import 'package:parrokit/features/community/activity/domain/entities/activity_cursor.dart';
import 'package:parrokit/features/community/activity/domain/repositories/activity_repository.dart';
import 'package:parrokit/features/community/activity/domain/usecases/get_activities_usecase.dart';
import 'package:parrokit/features/community/activity/presentation/activity_screen.dart';
import 'package:parrokit/features/community/activity/presentation/providers/activity_provider.dart';

class _MockUserProvider extends Mock implements UserProvider {}

class _FakeActivityRepository implements ActivityRepository {
  @override
  Future<ActivityPage> getActivities({
    required String userId,
    required String boardType,
    required String activityType,
    int limit = 100,
    ActivityCursor? startAfter,
  }) async {
    return const ActivityPage(items: [], hasMore: false);
  }
}

void main() {
  group('CommunityActivityScreen View', () {
    testWidgets('질문 활동 화면이 빈 상태로 렌더링된다', (tester) async {
      final userProvider = _MockUserProvider();
      when(userProvider.currentUser).thenReturn(null);

      await tester.pumpWidget(
        ChangeNotifierProvider<UserProvider>.value(
          value: userProvider,
          child: const MaterialApp(
            home: CommunityActivityScreen(
              boardType: 'question',
              activityType: 'commented',
              activityProviderFactory: _createActivityProvider,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 메뉴 이름과 같다(5차, 예전 '작성한 댓글').
      // 묶음 이름을 탭과 같게 바꿨다(5차): '질문 게시판' → '질문'.
      expect(find.text('질문 - 작성한 답변'), findsOneWidget);
      // 빈 화면도 어느 줄로 들어왔는지 말한다(5차, 예전 '아직 활동 내역이
      // 없습니다.').
      expect(find.text('아직 작성한 답변이 없어요.'), findsOneWidget);
      // 무엇을 하면 채워지는지도 알린다(5차).
      expect(find.text('글에 남긴 말이 여기에 모여요.'), findsOneWidget);
      // 답변은 질문 글에 다는 것이라 여기서 쓰러 가는 버튼은 두지 않는다.
      expect(find.text('질문하기'), findsNothing);
    });

    testWidgets('쓰기 활동이면 바로 쓰러 갈 버튼이 있다', (tester) async {
      final userProvider = _MockUserProvider();
      when(userProvider.currentUser).thenReturn(null);

      await tester.pumpWidget(
        ChangeNotifierProvider<UserProvider>.value(
          value: userProvider,
          child: const MaterialApp(
            home: CommunityActivityScreen(
              boardType: 'board',
              activityType: 'written',
              activityProviderFactory: _createActivityProvider,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('아직 작성한 글이 없어요.'), findsOneWidget);
      expect(find.text('글쓰기'), findsOneWidget);
    });

    testWidgets('투표는 글이 아니라 만드는 것이라 다른 말을 쓴다', (tester) async {
      final userProvider = _MockUserProvider();
      when(userProvider.currentUser).thenReturn(null);

      await tester.pumpWidget(
        ChangeNotifierProvider<UserProvider>.value(
          value: userProvider,
          child: const MaterialApp(
            home: CommunityActivityScreen(
              boardType: 'vote',
              activityType: 'written_posted',
              activityProviderFactory: _createActivityProvider,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('첫 투표를 만들면 여기에 모여요.'), findsOneWidget);
      expect(find.text('투표 만들기'), findsOneWidget);
    });
  });
}

ActivityProvider _createActivityProvider() {
  return ActivityProvider(
    getActivitiesUseCase: GetActivitiesUseCase(_FakeActivityRepository()),
  );
}
