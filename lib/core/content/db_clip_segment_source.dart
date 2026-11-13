import 'package:drift/drift.dart';
import 'package:parrokit/core/content/clip_sentence_match.dart';
import 'package:parrokit/data/local/app_database.dart';

/// 기기 클립 DB(Segments)에서 자막을 읽는 소스. 문장 상세의 '이 문장이 나오는
/// 클립'이 이것으로 실제 검색을 한다(5차). 예전엔 소스가 없어 누르면
/// "준비 중"만 나왔다.
///
/// 어느 클립을 볼지는 [visibleClips]가 정한다. 보관함과 같은 규칙(기기 클립,
/// 지금 계정의 서버 클립, 연결한 Drive 계정의 클립)을 쓰므로 다른 계정의
/// 클립 자막이 섞이지 않는다.
class DbClipSegmentSource implements ClipSegmentSource {
  const DbClipSegmentSource(this.db, this.visibleClips);

  final AppDatabase db;
  final Future<List<Clip>> Function() visibleClips;

  /// SQLite 변수 개수 제한을 넘지 않게 나눠 묻는다.
  static const _chunk = 500;

  @override
  Future<List<ClipSegmentRef>> loadSegments() async {
    final clips = await visibleClips();
    if (clips.isEmpty) return const [];
    final titles = {for (final c in clips) c.id: c.title};
    final ids = titles.keys.toList();
    final out = <ClipSegmentRef>[];
    for (var i = 0; i < ids.length; i += _chunk) {
      final part = ids.sublist(i, (i + _chunk).clamp(0, ids.length));
      final rows = await (db.select(db.segments)
            ..where((s) => s.clipId.isIn(part))
            ..orderBy([(s) => OrderingTerm(expression: s.startMs)]))
          .get();
      for (final row in rows) {
        out.add(ClipSegmentRef(
          clipId: row.clipId,
          clipTitle: titles[row.clipId] ?? '',
          segmentId: row.id,
          startMs: row.startMs,
          endMs: row.endMs,
          original: row.original,
          translation: row.trans,
        ));
      }
    }
    return out;
  }
}
