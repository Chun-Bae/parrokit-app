// 클립을 불러오는 중에 플레이어 화면을 닫았을 때의 회귀 테스트.
//
// 예전엔 dispose 뒤에도 await 뒤 코드가 이어 돌아, 닫힌 화면에 영상
// 컨트롤러를 새로 만들고(놓지 못한 채 남는다) dispose된 notifier를 다시 알렸다.
import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/state/provider/clip_provider.dart';
import 'package:parrokit/data/local/app_database.dart';
import 'package:parrokit/data/models/clip_view.dart';
import 'package:parrokit/features/collection/clip/player/presentation/clip_player_view_model.dart';

/// 클립 읽기를 테스트가 풀어 줄 때까지 붙잡는 ClipProvider.
class _GatedClipProvider extends ClipProvider {
  _GatedClipProvider(super.db);

  final gate = Completer<void>();

  @override
  Future<ClipView?> fetchClipById(int clipId) async {
    final view = await super.fetchClipById(clipId);
    await gate.future;
    return view;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('불러오는 중에 닫으면 컨트롤러를 만들지 않고 알리지도 않는다', () async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final clipId = await db.into(db.clips).insert(ClipsCompanion.insert(
          title: '여행',
          filePath: 'clips/a.mp4',
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

    final provider = _GatedClipProvider(db);
    final vm = ClipPlayerViewModel(clipId: clipId, clipProvider: provider);
    var notified = 0;
    vm.addListener(() => notified++);

    // 화면을 닫는다.
    vm.dispose();

    // 그 뒤에 클립 읽기가 끝난다. 예전엔 여기서 파일 경로를 풀고 컨트롤러를
    // 만들다 넘어진 뒤, dispose된 notifier를 알리다 오류가 났다.
    provider.gate.complete();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(vm.controller, isNull);
    expect(notified, 0);
  });
}
