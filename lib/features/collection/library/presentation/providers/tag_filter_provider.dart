import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart'; // ChangeNotifier
import 'package:drift/drift.dart';
import 'package:parrokit/data/local/app_database.dart';
import 'package:parrokit/data/models/clip_item.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';

/// [역할]
/// 라이브러리 탭의 '태그로 보기' 기능 상태 및 데이터 필터링 관리.
///
/// 사용자가 선택한 태그([activeTagNames])에 해당하는 클립들을 필터링하여 제공합니다.
/// - 태그 선택/해제 상태 관리
/// - OR 조건 필터링 로직 수행
/// - 필터링된 결과 데이터([filteredClipIds]) 및 캐싱 관리
class TagFilterProvider extends ChangeNotifier {
  final AppDatabase pdb;

  TagFilterProvider(this.pdb);

  // ─────────────────────────────────────────────────────────────────
  // State
  // ─────────────────────────────────────────────────────────────────

  /// tagId -> clipIds (OR 집합 계산용 역색인)
  final Map<int, Set<int>> _tagToClipIds = {};

  /// ClipItem 풀 캐시 (LRU 방식).
  /// DB 조회를 최소화하기 위해 사용됩니다.
  final _cache = <int, ClipItem>{};
  static const int _maxCacheSize = 400;

  /// 현재 필터링된 결과 클립 ID 목록
  List<int> filteredClipIds = [];

  /// 현재 선택된 태그 이름 목록
  final Set<String> _activeTagNames = {};
  List<String> get activeTagNames => _activeTagNames.toList();

  /// 중복 빌드 방지용 셋
  final Set<int> _building = {};
  String? _docsPath;

  /// 화면 렌더링용 최종 데이터 리스트 (깜빡임 방지)
  List<ClipItem> _items = const [];
  List<ClipItem> get items => _items;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// 결과 변경 감지용 버전 토큰 (UI 갱신 트리거)
  int _resultsVersion = 0;
  int get resultsVersion => _resultsVersion;

  final Map<int, ImageProvider> _thumbProviders = {}; // clipId -> provider
  ImageProvider? imageProviderFor(int clipId) => _thumbProviders[clipId];

  /// 디바운스 타이머
  Timer? _debounce;

  // ─────────────────────────────────────────────────────────────────
  // Actions
  // ─────────────────────────────────────────────────────────────────

  /// 태그 하나를 토글(추가/삭제)합니다.
  void toggleTag(String tagName) {
    if (_activeTagNames.contains(tagName)) {
      _activeTagNames.remove(tagName);
    } else {
      _activeTagNames.add(tagName);
    }
    notifyListeners();
    _scheduleApply();
  }

  /// 태그 하나를 추가합니다.
  void addTag(String tagName) {
    if (_activeTagNames.add(tagName)) {
      notifyListeners();
      _scheduleApply();
    }
  }

  /// 태그 하나를 삭제합니다.
  void removeTag(String tagName) {
    if (_activeTagNames.remove(tagName)) {
      notifyListeners();
      _scheduleApply();
    }
  }

  /// 모든 태그 선택을 해제합니다.
  void clearTags() {
    if (_activeTagNames.isNotEmpty) {
      _activeTagNames.clear();
      notifyListeners();
      _scheduleApply();
    }
  }

  /// 주어진 태그 목록으로 현재 선택을 대체합니다.
  void setTags(Iterable<String> tags) {
    _activeTagNames.clear();
    _activeTagNames.addAll(tags);
    notifyListeners();
    _scheduleApply();
  }

  /// 필터 적용을 예약합니다 (디바운스 처리).
  ///
  /// 연속적인 태그 변경 시 매번 DB를 조회하지 않고,
  /// 마지막 변경 후 300ms가 지나면 [applyNow]를 호출합니다.
  void _scheduleApply() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      applyOrByTagNames(_activeTagNames.toList()).then((_) => applyNow());
    });
  }

  // Legacy method support if needed, or remove scheduleApply(callback)
  // For refactoring, we replace the old scheduleApply with internal _scheduleApply

  bool _sameIds(List<ClipItem> a, List<ClipItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].clip.id != b[i].clip.id) return false;
    }
    return true;
  }

  /// 현재 필터 설정([activeTagNames])에 맞춰 데이터를 즉시 로드하고 상태를 갱신합니다.
  ///
  /// 캐싱된 데이터가 있다면 활용하고, 없다면 새로 로드([fetchItemsForCurrentFilter])합니다.
  /// applyNow 요청 번호. 들어오는 쪽이 셋이라(디바운스, showAll, startWatching)
  /// 겹칠 수 있다. 느린 조회가 나중에 끝나서 새 필터 결과를 덮지 않게 한다.
  int _applyRequestId = 0;

  Future<void> applyNow() async {
    final requestId = ++_applyRequestId;
    _setLoading(true);
    try {
      final next = await fetchItemsForCurrentFilter();

      // 내가 기다리는 동안 더 새 요청이 들어왔으면 이 결과는 버린다.
      if (requestId != _applyRequestId) return;

      // ✅ 결과가 이전과 동일하면 알림/교체 생략
      if (_sameIds(_items, next)) return;

      _items = next;
      _resultsVersion++;

      notifyListeners();
    } finally {
      if (requestId == _applyRequestId) _setLoading(false);
    }
  }

  void _setLoading(bool v) {
    if (_isLoading == v) return;
    _isLoading = v;
    notifyListeners();
  }

  /// DB 변경 감시 -> 필요한 캐시 무효화
  StreamSubscription? _clipsSub, _segmentsSub, _clipTagsSub;

  Future<void> showAll() async {
    // 모든 clip id 조회
    final rows = await (pdb.select(pdb.clips)
          ..orderBy([(c) => OrderingTerm.asc(c.id)]))
        .get();
    filteredClipIds = rows.map((c) => c.id).toList();
    await applyNow(); // 내부 items까지 채워서 깜빡임 최소화
  }

  /// DB 변경 사항을 감시하여 캐시를 무효화하고 UI를 갱신합니다.
  Future<void> startWatching() async {
    await _clipsSub?.cancel();
    await _segmentsSub?.cancel();
    await _clipTagsSub?.cancel();

    _clipsSub = (pdb.select(pdb.clips)).watch().listen((rows) {
      final ids = rows.map((e) => e.id).toSet();
      _cache.removeWhere((k, _) => !ids.contains(k));
      notifyListeners();
    });

    _segmentsSub = (pdb.select(pdb.segments)).watch().listen((rows) {
      final dirty = <int>{};
      for (final cid in rows.map((s) => s.clipId)) {
        if (_cache.containsKey(cid)) {
          _cache.remove(cid);
          dirty.add(cid);
        }
      }
      if (dirty.isNotEmpty) notifyListeners();
    });

    _clipTagsSub = (pdb.select(pdb.clipTags)).watch().listen((rows) {
      _tagToClipIds.clear();
      final dirty = <int>{};
      for (final ct in rows) {
        (_tagToClipIds[ct.tagId] ??= <int>{}).add(ct.clipId);
        if (_cache.containsKey(ct.clipId)) {
          _cache.remove(ct.clipId);
          dirty.add(ct.clipId);
        }
      }
      if (dirty.isNotEmpty) notifyListeners();
    });

    if (_activeTagNames.isNotEmpty) {
      await applyNow();
    }
  }

  @override
  void dispose() {
    _clearOnDispose();
    super.dispose();
  }

  void _clearOnDispose() {
    _cache.clear();
    _building.clear();
    _tagToClipIds.clear();
    _items = const [];
    _isLoading = false;
    _debounce?.cancel();
    _clipsSub?.cancel();
    _segmentsSub?.cancel();
    _clipTagsSub?.cancel();
    _activeTagNames.clear();
    filteredClipIds = [];
    _thumbProviders.clear();
    _resultsVersion = 0;
  }

  /// ======== 공개 API ========

  Future<List<int>> applyOrByTagNames(List<String> names) async {
    if (names.isEmpty) {
      filteredClipIds = [];
      notifyListeners();
      return filteredClipIds;
    }
    final rows =
        await (pdb.select(pdb.tags)..where((t) => t.name.isIn(names))).get();

    return applyOrByTagIds(rows.map((t) => t.id).toList());
  }

  Future<List<int>> applyOrByTagIds(List<int> ids) async {
    if (ids.isEmpty) {
      filteredClipIds = [];
      notifyListeners();
      return filteredClipIds;
    }
    await _ensureTagIndex(ids);
    final union = <int>{};
    for (final id in ids) {
      union.addAll(_tagToClipIds[id] ?? <int>{});
    }

    filteredClipIds = union.toList()..sort();
    notifyListeners();
    return filteredClipIds;
  }

  Future<List<ClipItem>> fetchItemsForCurrentFilter() async {
    final ids = filteredClipIds;
    if (ids.isEmpty) return [];
    final order = <int, int>{};
    for (var i = 0; i < ids.length; i++) {
      order[ids[i]] = i;
    }

    final out = <ClipItem>[];

    for (final id in ids) {
      final hit = _cache[id];
      if (hit != null) {
        _touch(id);
        out.add(hit);
      }
    }
    for (final id in ids) {
      if (_cache.containsKey(id)) continue;
      out.add(await _getOrBuild(id));
    }

    out.sort(
        (a, b) => (order[a.clip.id] ?? 0).compareTo(order[b.clip.id] ?? 0));
    return out;
  }

  /// ======== 내부 ========
  Future<void> _ensureTagIndex(Iterable<int> tagIds) async {
    final missing = <int>[];

    for (final id in tagIds) {
      if (!_tagToClipIds.containsKey(id)) {
        missing.add(id);
      }
    }
    if (missing.isEmpty) return;
    final jt = pdb.clipTags;
    final rows =
        await (pdb.select(jt)..where((jt) => jt.tagId.isIn(missing))).get();
    for (final id in missing) {
      _tagToClipIds[id] = <int>{};
    }
    for (final row in rows) {
      (_tagToClipIds[row.tagId] ??= <int>{}).add(row.clipId);
    }
  }

  Future<ClipItem> _getOrBuild(int clipId) async {
    final hit = _cache[clipId];
    if (hit != null) {
      _touch(clipId);
      return hit;
    }

    /// 다른 스레드에서 이미 빌드 중인 경우 대기
    if (_building.contains(clipId)) {
      final start = DateTime.now();
      while (_building.contains(clipId) &&
          DateTime.now().difference(start).inMilliseconds < 500) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      final again = _cache[clipId];
      if (again != null) return again;
    }

    _building.add(clipId);
    try {
      // clip
      final clip = await (pdb.select(pdb.clips)
            ..where((c) => c.id.equals(clipId))
            ..limit(1))
          .getSingleOrNull();
      if (clip == null) throw StateError('Clip not found: $clipId');

      // segments
      final segments = await (pdb.select(pdb.segments)
            ..where((s) => s.clipId.equals(clipId))
            ..orderBy([(s) => OrderingTerm.asc(s.startMs)]))
          .get();

      // tags
      final jt = pdb.clipTags;
      final tagRows = await (pdb.select(pdb.tags).join([
        innerJoin(jt, jt.tagId.equalsExp(pdb.tags.id)),
      ])
            ..where(jt.clipId.equals(clipId)))
          .get();
      final tags = [for (final r in tagRows) r.readTable(pdb.tags)];

      // thumbnail

      Uint8List? thumb;
      try {
        final thumbnailPath = clip.thumbnailFilePath;
        if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
          final thumbnailFile = File(await _absolutePathFor(thumbnailPath));
          if (await thumbnailFile.exists()) {
            thumb = await thumbnailFile.readAsBytes();
          }
        }
        if (thumb == null) {
          final abs = await _absolutePathFor(clip.filePath);
          thumb = await VideoThumbnail.thumbnailData(
            video: abs,
            imageFormat: ImageFormat.JPEG,
            quality: 70,
            timeMs: 0,
          );
        }
      } catch (_) {
        thumb = null;
      }

      if (thumb != null) {
        _thumbProviders[clipId] = MemoryImage(thumb);
      }
      final item = ClipItem(
        clip: clip,
        segments: segments,
        tags: tags,
        thumbnail: thumb,
      );

      _put(clipId, item);
      return item;
    } finally {
      _building.remove(clipId);
    }
  }

  Future<String> _absolutePathFor(String path) async {
    if (path.startsWith('/')) return path;
    _docsPath ??= (await getApplicationDocumentsDirectory()).path;
    return '$_docsPath/$path';
  }

  /// LRU 갱신
  void _touch(int id) {
    final v = _cache.remove(id);
    if (v != null) _cache[id] = v;
  }

  void _put(int id, ClipItem item) {
    _cache[id] = item;
    if (_cache.length > _maxCacheSize) {
      final evictId = _cache.keys.first;
      _cache.remove(evictId);
      _thumbProviders.remove(evictId);
    }
  }
}
