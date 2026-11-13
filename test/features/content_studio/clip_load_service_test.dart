import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/state/provider/clip_provider.dart';
import 'package:parrokit/data/local/app_database.dart';
import 'package:parrokit/features/content-studio/captioning/data/services/clip_load_service.dart';

void main() {
  test('보관함 목록을 불러오지 않았어도 편집할 클립을 DB에서 찾는다', () async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    final folder = await db.collectionsDao.findOrCreate('여행/일본', 'local');
    // 기기 클립은 재생 파일이 있어야 열린다. 절대 경로로 둔다.
    final dir = await Directory.systemTemp.createTemp('clip_load');
    addTearDown(() => dir.delete(recursive: true));
    final video = File('${dir.path}/clip.mp4')..writeAsBytesSync([1, 2, 3]);
    final clipId = await db.into(db.clips).insert(ClipsCompanion.insert(
          title: '오사카 역',
          filePath: video.path,
          durationMs: 6000,
          collectionId: Value(folder.id),
        ));
    await db.into(db.segments).insert(SegmentsCompanion.insert(
        clipId: clipId,
        startMs: 0,
        endMs: 1500,
        original: 'Where is the station?',
        pron: '',
        trans: '역이 어디예요?'));
    final tagId =
        await db.into(db.tags).insert(TagsCompanion.insert(name: '여행'));
    await db
        .into(db.clipTags)
        .insert(ClipTagsCompanion.insert(clipId: clipId, tagId: tagId));

    // 예전 코드가 보던 clipProvider.clips는 비어 있다.
    final provider = ClipProvider(db);
    expect(provider.clips, isEmpty);

    final result =
        await ClipLoadService(clipProvider: provider).loadForEdit(clipId);
    expect(result.formData.clipTitle, '오사카 역');
    expect(result.formData.collectionName, '여행/일본');
    expect(result.formData.tags, ['여행']);
    expect(result.formData.segments.single.original, 'Where is the station?');
    expect(result.formData.segments.single.end, '00:01.500');
  });
}
