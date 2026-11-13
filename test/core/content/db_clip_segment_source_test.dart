import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/clip_sentence_match.dart';
import 'package:parrokit/core/content/db_clip_segment_source.dart';
import 'package:parrokit/data/local/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.withExecutor(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<Clip> clip(String title, List<(int, String)> lines) async {
    final id = await db.into(db.clips).insert(
        ClipsCompanion.insert(title: title, filePath: '', durationMs: 60000));
    for (final (start, text) in lines) {
      await db.into(db.segments).insert(SegmentsCompanion.insert(
          clipId: id,
          startMs: start,
          endMs: start + 1000,
          original: text,
          pron: '',
          trans: '뜻'));
    }
    return (db.select(db.clips)..where((c) => c.id.equals(id))).getSingle();
  }

  test('보이는 클립의 자막만 읽어 클립 제목과 함께 돌려준다', () async {
    final mine = await clip('여행 브이로그', [(65000, 'Hello there!'), (1000, 'Bye')]);
    await clip('다른 계정 클립', [(0, 'Hello there!')]);

    final source = DbClipSegmentSource(db, () async => [mine]);
    final segments = await source.loadSegments();

    expect(segments.map((s) => s.original), ['Bye', 'Hello there!']);
    expect(segments.every((s) => s.clipTitle == '여행 브이로그'), isTrue);
    expect(segments.last.startMs, 65000);
    expect(segments.last.translation, '뜻');
  });

  test('보이는 클립이 없으면 DB를 묻지 않고 빈 목록', () async {
    final source = DbClipSegmentSource(db, () async => const []);
    expect(await source.loadSegments(), isEmpty);
  });

  test('찾기와 이어 쓰면 내 문장이 나오는 자막을 찾는다', () async {
    final mine = await clip('여행 브이로그', [(65000, 'Hello there!'), (0, 'Good morning')]);
    final finder = ClipSentenceFinder(DbClipSegmentSource(db, () async => [mine]));
    final found = await finder.find('hello there');
    expect(found, hasLength(1));
    expect(found.single.kind, ClipMatchKind.exact);
    expect(found.single.segment.clipTitle, '여행 브이로그');
  });
}
