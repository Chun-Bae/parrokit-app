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
    testWidgets('질문 게시판 활동 화면이 빈 상태로 렌더링된다', (tester) async {
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
      expect(find.text('질문 게시판 - 작성한 답변'), findsOneWidget);
      expect(find.text('아직 활동 내역이 없습니다.'), findsOneWidget);
    });
  });
}

ActivityProvider _createActivityProvider() {
  return ActivityProvider(
    getActivitiesUseCase: GetActivitiesUseCase(_FakeActivityRepository()),
  );
}
