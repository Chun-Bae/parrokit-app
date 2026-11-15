// '최근 본 클립' 기록. 같은 클립을 다시 봐도 줄이 늘지 않고 차례만 올라가야
// 하고, 너무 쌓이면 오래된 것부터 버려야 한다. 손으로 쓴 SQL이라 바뀌면
// 조용히 깨질 수 있어 테스트로 묶어 둔다.

import 'dart:async';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/domain/collection_clip/domain/repositories/clip_repository.dart';
import 'package:parrokit/core/state/provider/clip_activity_provider.dart';
import 'package:parrokit/data/local/app_database.dart';

class _FakeClipRepository implements ClipRepository {
  // 최근 목록을 그릴 때 썸네일만 읽는다. 나머지는 이 테스트에서 안 쓴다.
  @override
  Future<Uint8List?> loadThumbnailBytes(Clip clip) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// 썸네일을 붙잡아 두는 가짜 저장소. 받아오는 사이에 dispose가 나도록 쓴다.
class _SlowClipRepository implements ClipRepository {
  final held = Completer<void>();
  final started = Completer<void>();

  @override
  Future<Uint8List?> loadThumbnailBytes(Clip clip) async {
    if (!started.isCompleted) started.complete();
    await held.future;
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;
  late ClipActivityProvider provider;

  setUp(() {
    db = AppDatabase.withExecutor(NativeDatabase.memory());
    provider = ClipActivityProvider(db, _FakeClipRepository());
  });

  tearDown(() async {
    provider.dispose();
    await db.close();
  });

  Future<int> newClip(String title) => db.into(db.clips).insert(
        ClipsCompanion.insert(
          title: title,
          filePath: '/tmp/$title.mp4',
          durationMs: 1000,
          collectionId: const Value.absent(),
        ),
      );

  /// 오래 본 순서대로 clipId 목록.
  Future<List<int>> views() async {
    final rows = await db
        .customSelect('SELECT clip_id FROM recent_clip_views ORDER BY last_seq')
        .get();
    return [for (final r in rows) r.data['clip_id'] as int];
  }

  test('같은 클립을 다시 봐도 줄이 늘지 않고 맨 뒤로 간다', () async {
    final a = await newClip('a');
    final b = await newClip('b');

    await provider.logRecent(a);
    await provider.logRecent(b);
    expect(await views(), [a, b]);

    await provider.logRecent(a);
    expect(await views(), [b, a], reason: '다시 본 클립이 가장 최근이 된다');
  });

  test('본 적 없는 클립은 새로 적는다', () async {
    final a = await newClip('a');
    final b = await newClip('b');
    final c = await newClip('c');

    for (final id in [a, b, c]) {
      await provider.logRecent(id);
    }
    expect(await views(), [a, b, c]);
  });

  test('정리하지 않으면 100개가 넘어도 그대로 둔다', () async {
    for (var i = 0; i < 101; i++) {
      await provider.logRecent(await newClip('c$i'));
    }
    expect((await views()).length, 101);
  });

  test('정리하면 최근 100개만 남는다', () async {
    final ids = <int>[];
    for (var i = 0; i < 105; i++) {
      final id = await newClip('c$i');
      ids.add(id);
      await provider.logRecent(id, prune: true);
    }

    final left = await views();
    expect(left.length, 100);
    expect(left.first, ids[5], reason: '오래된 것부터 버린다');
    expect(left.last, ids.last);
  });

  test('100개 이하면 정리해도 지우지 않는다', () async {
    final ids = <int>[];
    for (var i = 0; i < 100; i++) {
      final id = await newClip('c$i');
      ids.add(id);
      await provider.logRecent(id, prune: true);
    }
    expect((await views()).length, 100);
    expect((await views()).first, ids.first);
  });

  test('클립을 지우면 본 기록도 함께 사라진다', () async {
    final a = await newClip('a');
    await provider.logRecent(a);
    expect(await views(), [a]);

    await (db.delete(db.clips)..where((c) => c.id.equals(a))).go();
    expect(await views(), isEmpty);
  });

  test('썸네일을 받는 동안 화면이 사라져도 터지지 않는다', () async {
    final slowDb = AppDatabase.withExecutor(NativeDatabase.memory());
    addTearDown(slowDb.close);
    final repo = _SlowClipRepository();
    final slow = ClipActivityProvider(slowDb, repo);

    final clipId = await slowDb.into(slowDb.clips).insert(
          ClipsCompanion.insert(
            title: 'slow',
            filePath: '/tmp/slow.mp4',
            durationMs: 1000,
          ),
        );
    await slow.logRecent(clipId);
    await repo.started.future; // 썸네일을 받는 중

    slow.dispose();
    repo.held.complete(); // 이제야 돌아온다
    await Future<void>.delayed(const Duration(milliseconds: 20));
    // 전에는 여기서 'A ClipActivityProvider was used after being disposed.'
    expect(slow.recent6, isEmpty);
  });
}
