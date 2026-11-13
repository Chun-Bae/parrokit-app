import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/collection/library/presentation/folder_tree.dart';

void main() {
  test('경로 이름을 정규화한다', () {
    expect(normalizeFolderPath('  여행 / 일본/ '), '여행/일본');
    expect(normalizeFolderPath('일상회화'), '일상회화');
    expect(normalizeFolderPath(' / '), '');
  });

  test('이름 경로로 폴더 안의 폴더를 만들고 수를 합친다', () {
    final (roots, byPath) = buildFolderTree(
      [(1, '여행'), (2, '여행/일본'), (3, '여행/일본/오사카'), (4, '일상회화')],
      {1: 1, 2: 2, 3: 3, 4: 5},
    );
    expect(roots.map((f) => f.name), ['여행', '일상회화']);
    final trip = byPath['여행']!;
    expect(trip.directCount, 1);
    expect(trip.totalCount, 6);
    expect(trip.children.map((f) => f.name), ['일본']);
    expect(byPath['여행/일본/오사카']!.trail.map((f) => f.name),
        ['여행', '일본', '오사카']);
  });

  test('중간 폴더는 컬렉션이 없어도 생기고, 위치가 달라도 같은 이름이면 합친다', () {
    final (roots, byPath) = buildFolderTree(
      [(1, '영화/마블'), (2, '영화/마블 ')], // 로컬·Drive에 같은 이름
      {1: 2, 2: 1},
    );
    expect(roots.single.name, '영화');
    expect(roots.single.collectionIds, isEmpty);
    expect(byPath['영화/마블']!.collectionIds, {1, 2});
    expect(byPath['영화']!.totalCount, 3);
  });

  test('클립이 없는 폴더는 하위까지 비면 빠진다', () {
    final (roots, byPath) = buildFolderTree(
      [(1, '빈 폴더/더 빈 폴더'), (2, '찬 폴더/빈 하위'), (3, '찬 폴더')],
      {3: 1},
    );
    expect(roots.map((f) => f.name), ['찬 폴더']);
    expect(roots.single.children, isEmpty);
    expect(byPath.containsKey('빈 폴더'), isFalse);
  });
}
