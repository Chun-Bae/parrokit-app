/// 클립 폴더 트리. 폴더 안에 폴더를 둘 수 있다(5차, 사용자 요청).
///
/// 데이터는 바꾸지 않는다. 폴더(컬렉션) 이름에 '/'를 넣어 경로로 쓴다.
/// "여행/일본"은 "여행" 안의 "일본"이다. 새 클립 화면은 원래 위치(로컬·서버·
/// Drive)가 달라도 이름이 같으면 한 폴더로 합치므로, 경로도 같은 방식으로 합쳐진다.
/// 이름은 이미 서버·Drive로 동기화되므로 DB 마이그레이션이나 규칙 변경이 없다.
/// 예전 화면은 "여행/일본"을 그냥 한 이름으로 보여준다.
class ClipFolder {
  ClipFolder(this.path, {this.parent});

  /// 정규화한 전체 경로. 예: '여행/일본'
  final String path;
  final ClipFolder? parent;

  /// 이 경로와 이름이 정확히 같은 컬렉션들(위치마다 하나씩일 수 있다).
  final Set<int> collectionIds = {};

  /// 이 폴더에 바로 들어 있는 클립 수.
  int directCount = 0;
  final List<ClipFolder> children = [];

  String get name => path.split('/').last;

  /// 하위 폴더까지 합친 클립 수.
  int get totalCount =>
      directCount + children.fold(0, (sum, c) => sum + c.totalCount);

  /// 맨 위부터 이 폴더까지. 예: [여행, 일본]
  List<ClipFolder> get trail {
    final out = <ClipFolder>[];
    for (ClipFolder? f = this; f != null; f = f.parent) {
      out.insert(0, f);
    }
    return out;
  }
}

/// '  여행 / 일본/ ' → '여행/일본'. 빈 칸은 버린다. 다 비면 ''.
String normalizeFolderPath(String name) => name
    .split('/')
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .join('/');

/// 맨 위 폴더 목록(이름 순)과 경로 → 폴더 표를 만든다. 클립이 하나도 없는
/// 폴더(하위까지)는 뺀다. [keepEmpty]면 빈 폴더도 둔다(보관함에서 '새 폴더'로
/// 폴더만 만들 수 있게 된 뒤로는 빈 폴더도 사용자가 만든 것이다, 5차).
(List<ClipFolder>, Map<String, ClipFolder>) buildFolderTree(
  Iterable<(int, String)> collections,
  Map<int, int> clipCountByCollection, {
  bool keepEmpty = false,
}) {
  final byPath = <String, ClipFolder>{};

  ClipFolder ensure(String path) {
    final existing = byPath[path];
    if (existing != null) return existing;
    final cut = path.lastIndexOf('/');
    final parent = cut < 0 ? null : ensure(path.substring(0, cut));
    final folder = ClipFolder(path, parent: parent);
    parent?.children.add(folder);
    byPath[path] = folder;
    return folder;
  }

  for (final (id, rawName) in collections) {
    final path = normalizeFolderPath(rawName);
    if (path.isEmpty) continue;
    final folder = ensure(path);
    folder.collectionIds.add(id);
    folder.directCount += clipCountByCollection[id] ?? 0;
  }

  void prune(List<ClipFolder> list) {
    if (!keepEmpty) list.removeWhere((f) => f.totalCount == 0);
    list.sort((a, b) => a.name.compareTo(b.name));
    for (final f in list) {
      prune(f.children);
    }
  }

  final roots = byPath.values.where((f) => f.parent == null).toList();
  prune(roots);
  if (!keepEmpty) byPath.removeWhere((_, f) => f.totalCount == 0);
  return (roots, byPath);
}
