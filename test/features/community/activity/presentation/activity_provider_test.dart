import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/community/activity/domain/entities/activity_cursor.dart';
import 'package:parrokit/features/community/activity/domain/entities/activity_item.dart';
import 'package:parrokit/features/community/activity/domain/entities/activity_page.dart';
import 'package:parrokit/features/community/activity/domain/repositories/activity_repository.dart';
import 'package:parrokit/features/community/activity/domain/usecases/get_activities_usecase.dart';
import 'package:parrokit/features/community/activity/presentation/providers/activity_provider.dart';

/// 조회를 수동으로 끝낼 수 있는 저장소.
///
/// 활동 유형을 빠르게 두 번 바꾸면 두 조회가 겹친다. 네트워크 사정에 따라
/// 먼저 보낸 조회가 늦게 끝날 수 있는데, 그때 늦게 온 옛 결과가 새 목록을
/// 덮어쓰면 사용자는 다른 탭의 내용을 보게 된다.
class _ManualActivityRepository implements ActivityRepository {
  final Map<String, Completer<ActivityPage>> pending = {};
  final List<String> requested = [];

  @override
  Future<ActivityPage> getActivities({
    required String userId,
    required String boardType,
    required String activityType,
    int limit = 100,
    ActivityCursor? startAfter,
  }) {
    requested.add(activityType);
    final completer = Completer<ActivityPage>();
    pending[activityType] = completer;
    return completer.future;
  }

  void complete(String activityType, List<String> ids, {bool hasMore = false}) {
    pending.remove(activityType)!.complete(
          ActivityPage(
            items: ids.map(_item).toList(),
            hasMore: hasMore,
            nextCursor: hasMore
                ? ActivityCursor(sortValue: DateTime(2026), documentId: ids.last)
                : null,
          ),
        );
  }

  void fail(String activityType, Object error) {
    pending.remove(activityType)!.completeError(error);
  }

  static ActivityItem _item(String id) => ActivityItem(
        id: id,
        sourcePostId: 'post_$id',
        title: '글 $id',
        content: '내용 $id',
        createdAt: DateTime(2026, 1, 1),
        boardType: 'board',
        activityType: 'written',
      );
}

void main() {
  late _ManualActivityRepository repository;
  late ActivityProvider provider;

  setUp(() {
    repository = _ManualActivityRepository();
    provider = ActivityProvider(
      getActivitiesUseCase: GetActivitiesUseCase(repository),
    );
  });

  Future<void> fetch(String activityType) {
    return provider.fetchActivities(
      userId: 'user_1',
      boardType: 'board',
      activityType: activityType,
    );
  }

  test('늦게 끝난 옛 조회가 새 목록을 덮어쓰지 않는다', () async {
    final first = fetch('written');
    final second = fetch('commented');

    // 나중에 보낸 조회가 먼저 끝난다.
    repository.complete('commented', ['c1', 'c2']);
    await second;
    expect(provider.activities.map((a) => a.id), ['c1', 'c2']);

    // 먼저 보낸 조회가 뒤늦게 끝난다. 이 결과는 버려야 한다.
    repository.complete('written', ['w1', 'w2', 'w3']);
    await first;

    expect(provider.activities.map((a) => a.id), ['c1', 'c2']);
    expect(provider.isLoading, isFalse);
  });

  test('늦게 끝난 옛 조회의 실패가 새 목록에 오류로 뜨지 않는다', () async {
    final first = fetch('written');
    final second = fetch('commented');

    repository.complete('commented', ['c1']);
    await second;

    repository.fail('written', Exception('끊김'));
    await first;

    expect(provider.error, isNull);
    expect(provider.activities.map((a) => a.id), ['c1']);
    expect(provider.isLoading, isFalse);
  });

  test('늦게 끝난 옛 조회가 로딩 표시를 먼저 끄지 않는다', () async {
    final first = fetch('written');
    final second = fetch('commented');

    // 옛 조회가 먼저 끝난다. 새 조회는 아직 돌고 있다.
    repository.complete('written', ['w1']);
    await first;

    expect(provider.isLoading, isTrue,
        reason: '새 조회가 아직 안 끝났으므로 로딩이 유지돼야 한다');
    expect(provider.activities, isEmpty);

    repository.complete('commented', ['c1']);
    await second;
    expect(provider.isLoading, isFalse);
    expect(provider.activities.map((a) => a.id), ['c1']);
  });

  test('loadMore가 도는 중에 탭을 바꾸면 옛 페이지가 뒤에 붙지 않는다', () async {
    final initial = fetch('written');
    repository.complete('written', ['w1', 'w2'], hasMore: true);
    await initial;
    expect(provider.activities.map((a) => a.id), ['w1', 'w2']);
    expect(provider.hasMore, isTrue);

    // 다음 페이지를 읽는 중에 사용자가 다른 활동 유형으로 넘어간다.
    final more = provider.loadMore();
    final switched = fetch('commented');

    repository.complete('commented', ['c1']);
    await switched;

    repository.complete('written', ['w3', 'w4']);
    await more;

    expect(provider.activities.map((a) => a.id), ['c1']);
  });

  test('같은 조회가 정상으로 끝나면 목록과 커서가 채워진다', () async {
    final future = fetch('written');
    repository.complete('written', ['w1', 'w2'], hasMore: true);
    await future;

    expect(provider.activities.map((a) => a.id), ['w1', 'w2']);
    expect(provider.hasMore, isTrue);
    expect(provider.error, isNull);
    expect(provider.isLoading, isFalse);
  });

  test('불러오는 중에 화면을 닫아도 오류 없이 끝난다', () async {
    final loading = fetch('written');
    var notified = 0;
    provider.addListener(() => notified++);

    provider.dispose();
    repository.complete('written', ['w1']);
    await loading;

    expect(notified, 0);
  });
}
