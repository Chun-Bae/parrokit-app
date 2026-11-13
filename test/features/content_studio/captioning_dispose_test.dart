// 편집할 클립을 불러오는 중에 화면을 닫았을 때의 회귀 테스트.
//
// 예전엔 닫힌 뒤에도 불러오기가 이어져 해제된 입력칸에 쓰다 넘어지고, 닫은
// 화면 위로 '클립을 불러오지 못했어요'가 뜨고, 해제된 notifier를 알렸다.
import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/state/provider/clip_provider.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/data/local/app_database.dart';
import 'package:parrokit/data/models/clip_view.dart';
import 'package:parrokit/features/content-studio/captioning/presentation/providers/captioning_provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

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

class _User extends Fake implements UserProvider {}

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);

  final Directory root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root.path;

  @override
  Future<String?> getTemporaryPath() async => root.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('captioning_dispose');
    File('${root.path}/clips/a.mp4')
      ..createSync(recursive: true)
      ..writeAsBytesSync([0, 1, 2]);
    addTearDown(() => root.deleteSync(recursive: true));
    PathProviderPlatform.instance = _FakePathProvider(root);
  });

  test('불러오는 중에 닫으면 입력칸에 쓰지 않고 알리지도 않는다', () async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final clipId = await db.into(db.clips).insert(ClipsCompanion.insert(
          title: '여행',
          filePath: 'clips/a.mp4',
          durationMs: 3000,
        ));

    final clips = _GatedClipProvider(db);
    final vm = CaptioningProvider(
      clipProvider: clips,
      userProvider: _User(),
      collectionsDao: db.collectionsDao,
      clipId: clipId,
    );
    var notified = 0;
    vm.addListener(() => notified++);

    vm.dispose();
    clips.gate.complete();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(notified, 0);
  });

  test('닫지 않았으면 불러온 제목을 채운다', () async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final clipId = await db.into(db.clips).insert(ClipsCompanion.insert(
          title: '여행',
          filePath: 'clips/a.mp4',
          durationMs: 3000,
        ));

    final clips = _GatedClipProvider(db);
    final vm = CaptioningProvider(
      clipProvider: clips,
      userProvider: _User(),
      collectionsDao: db.collectionsDao,
      clipId: clipId,
    );
    addTearDown(vm.dispose);

    clips.gate.complete();
    for (var i = 0; i < 100 && vm.isLoadingForEdit; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(vm.isLoadingForEdit, isFalse);
    expect(vm.titleCtl.text, '여행');
  });
}
