// 쇼츠 목록이 끝에 닿았을 때 다음 배치를 당겨오는 규칙과, 앞 배치를 버린
// 뒤에도 계속 당겨올 수 있는지를 확인한다.
//
// 한 번 고장났던 곳이다. "이 길이에서는 이미 당겨왔다"는 기억을
// removeItems에서 지우지 않아, 앞 10개를 버려 길이가 기억된 값과 같아지면
// 그 뒤로 무한 스크롤이 멈추고 같은 10개만 돌았다.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/data/local/app_database.dart';
import 'package:parrokit/data/models/clip_item.dart';
import 'package:parrokit/core/state/provider/clip_provider.dart';
import 'package:parrokit/features/collection/clip/shorts/data/shorts_repository.dart';
import 'package:parrokit/features/collection/clip/shorts/presentation/providers/shorts_provider.dart';

/// 정해 둔 배치를 순서대로 돌려주는 가짜 저장소.
class _FakeShortsRepository extends ShortsRepository {
  _FakeShortsRepository(super.db, this.batches);

  final List<List<ClipItem>> batches;
  int calls = 0;

  @override
  Future<List<ClipItem>> getRandomClips({required int limit}) async {
    calls++;
    if (batches.isEmpty) return const [];
    return batches.removeAt(0);
  }
}

void main() {
  late AppDatabase db;
  late ClipProvider clipProvider;

  setUp(() {
    db = AppDatabase.withExecutor(NativeDatabase.memory());
    clipProvider = ClipProvider(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<ClipItem> clipItem(String title) async {
    final id = await db.into(db.clips).insert(
          ClipsCompanion.insert(
            title: title,
            filePath: '/tmp/$title.mp4',
            durationMs: 1000,
          ),
        );
    final clip =
        await (db.select(db.clips)..where((c) => c.id.equals(id))).getSingle();
    return ClipItem(clip: clip, tags: const [], segments: const []);
  }

  Future<List<ClipItem>> batch(String prefix, int count) async =>
      [for (var i = 0; i < count; i++) await clipItem('$prefix$i')];

  test('끝에서 5개 안으로 들어오면 다음 배치를 당겨온다', () async {
    final repo = _FakeShortsRepository(
        db, [await batch('a', 10), await batch('b', 10)]);
    final provider = ShortsProvider(repo, clipProvider);

    await provider.loadInitial();
    expect(provider.shorts.length, 10);

    // 아직 멀다.
    await provider.prefetchNextBatch(4);
    expect(provider.shorts.length, 10);

    await provider.prefetchNextBatch(5);
    expect(provider.shorts.length, 20);
    expect(repo.calls, 2);
  });

  test('같은 길이에서 여러 번 불러도 한 번만 당겨온다', () async {
    final repo = _FakeShortsRepository(
        db, [await batch('a', 10), await batch('b', 10), await batch('c', 10)]);
    final provider = ShortsProvider(repo, clipProvider);

    await provider.loadInitial();
    await provider.prefetchNextBatch(5);
    await provider.prefetchNextBatch(6);
    await provider.prefetchNextBatch(9);
    expect(provider.shorts.length, 20);
    expect(repo.calls, 2);
  });

  test('목록이 비었거나 인덱스가 음수면 당겨오지 않는다', () async {
    final repo = _FakeShortsRepository(db, [await batch('a', 10)]);
    final provider = ShortsProvider(repo, clipProvider);

    await provider.prefetchNextBatch(0);
    expect(repo.calls, 0);

    await provider.loadInitial();
    await provider.prefetchNextBatch(-1);
    expect(repo.calls, 1);
  });

  test('앞 배치를 버려 길이가 되돌아가도 다음 배치를 당겨올 수 있다', () async {
    final repo = _FakeShortsRepository(
        db, [await batch('a', 10), await batch('b', 10), await batch('c', 10)]);
    final provider = ShortsProvider(repo, clipProvider);

    await provider.loadInitial();
    await provider.prefetchNextBatch(5); // 20개
    provider.removeItems(10); // 다시 10개, 기억은 20이었다

    await provider.prefetchNextBatch(5);
    expect(provider.shorts.length, 20,
        reason: '길이가 10으로 돌아간 뒤에도 다음 배치를 받아야 한다');
    expect(repo.calls, 3);
    expect(provider.shorts.first.clip.title, 'b0');
  });

  test('버릴 개수가 목록보다 많거나 0 이하면 그대로 둔다', () async {
    final repo = _FakeShortsRepository(db, [await batch('a', 10)]);
    final provider = ShortsProvider(repo, clipProvider);

    await provider.loadInitial();
    provider.removeItems(0);
    provider.removeItems(-3);
    provider.removeItems(11);
    expect(provider.shorts.length, 10);

    provider.removeItems(10);
    expect(provider.shorts, isEmpty);
  });
}
