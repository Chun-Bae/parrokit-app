// 빌려 쓰는 플레이어를 언제 다시 읽는지(5차 4단계).
//
// 화면을 나가도 플레이어가 살아 있어서, 같은 클립으로 돌아오면 다시 읽지
// 않고 듣던 자리에서 잇는다. 다만 편집하고 돌아오면 영상이나 구간이
// 바뀌었을 수 있어 반드시 다시 읽어야 한다.

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/state/provider/clip_provider.dart';
import 'package:parrokit/data/local/app_database.dart';
import 'package:parrokit/features/collection/clip/player/presentation/clip_player_view_model.dart';
import 'package:parrokit/features/collection/clip/player/presentation/engine/clip_player_engine.dart';

/// 실제 영상 없이 부른 것만 적어 두는 창구.
class _FakeEngine extends ChangeNotifier implements ClipPlayerEngine {
  final opens = <String>[];
  bool ready = true;

  @override
  bool get keepsPlayingInBackground => true;

  @override
  bool get isReady => ready;

  @override
  bool get isPlaying => false;

  @override
  Duration get position => Duration.zero;

  @override
  Duration get duration => const Duration(seconds: 3);

  @override
  double get aspectRatio => 16 / 9;

  @override
  Size get size => const Size(1280, 720);

  @override
  String get title => '';

  @override
  Future<void> open(String absolutePath,
      {double speed = 1.0, String title = ''}) async {
    opens.add(absolutePath);
  }

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> seekTo(Duration position) async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> setLooping(bool value) async {}

  @override
  Future<void> close() async {}

  @override
  Widget surface() => const SizedBox.shrink();

  @override
  Future<void> dispose() async => super.dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String videoPath;

  setUp(() {
    // 플레이어는 파일이 실제로 있는지 본다. 빈 파일을 하나 둔다.
    final file = File('${Directory.systemTemp.path}/parrokit_reuse_test.mp4');
    file.writeAsBytesSync(<int>[0]);
    videoPath = file.path;
  });

  Future<(AppDatabase, ClipProvider, int)> seed() async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final clipId = await db.into(db.clips).insert(ClipsCompanion.insert(
          title: '여행',
          filePath: videoPath,
          durationMs: 3000,
          collectionId: const Value(null),
        ));
    await db.into(db.segments).insert(SegmentsCompanion.insert(
          clipId: clipId,
          startMs: 0,
          endMs: 1000,
          original: 'hi',
          pron: '',
          trans: '안녕',
        ));
    return (db, ClipProvider(db), clipId);
  }

  test('이미 읽어 둔 플레이어로 돌아오면 다시 읽지 않는다', () async {
    final (_, provider, clipId) = await seed();
    final engine = _FakeEngine();
    final vm = ClipPlayerViewModel(
      clipId: clipId,
      clipProvider: provider,
      engine: engine,
      engineAlreadyLoaded: true,
    );
    addTearDown(vm.dispose);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(engine.opens, isEmpty, reason: '듣던 자리가 끊기면 안 된다');
  });

  test('들고 있는 것이 없으면 읽는다', () async {
    final (_, provider, clipId) = await seed();
    final engine = _FakeEngine()..ready = false;
    final vm = ClipPlayerViewModel(
      clipId: clipId,
      clipProvider: provider,
      engine: engine,
      engineAlreadyLoaded: true,
    );
    addTearDown(vm.dispose);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(vm.errorMessage, isNull, reason: '읽기가 넘어지면 안 된다');
    expect(engine.opens, [videoPath]);
  });

  test('편집하고 돌아오면 반드시 다시 읽는다', () async {
    final (_, provider, clipId) = await seed();
    final engine = _FakeEngine();
    final vm = ClipPlayerViewModel(
      clipId: clipId,
      clipProvider: provider,
      engine: engine,
      engineAlreadyLoaded: true,
    );
    addTearDown(vm.dispose);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(engine.opens, isEmpty);

    await vm.reloadAfterEdit();

    expect(engine.opens, [videoPath],
        reason: '영상이나 구간이 바뀌었을 수 있다');
  });
}
