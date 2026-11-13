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

  group('까다로운 이름', () {
    test('깊은 경로(6단계)도 끝까지 이어지고 수가 맨 위까지 합쳐진다', () {
      final (roots, byPath) =
          buildFolderTree([(1, 'a/b/c/d/e/f')], {1: 2});
      expect(roots.single.totalCount, 2);
      expect(byPath['a/b/c/d/e/f']!.trail.map((f) => f.name),
          ['a', 'b', 'c', 'd', 'e', 'f']);
    });

    test("빈 칸('여행//일본', 끝의 '/')은 무시하고 같은 폴더가 된다", () {
      final (_, byPath) = buildFolderTree(
          [(1, '여행//일본'), (2, '여행/일본/'), (3, '/여행/')], {1: 1, 2: 1, 3: 1});
      expect(byPath['여행/일본']!.collectionIds, {1, 2});
      expect(byPath['여행']!.collectionIds, {3});
    });

    test('특수문자·이모지·점은 이름 그대로 쓴다', () {
      final (roots, byPath) = buildFolderTree(
          [(1, 'C++ 공부/C# 기초'), (2, '🎬 영화/v1.2'), (3, '...')],
          {1: 1, 2: 1, 3: 1});
      expect(roots.map((f) => f.name), containsAll(['C++ 공부', '🎬 영화', '...']));
      expect(byPath['C++ 공부/C# 기초']!.name, 'C# 기초');
      expect(byPath['🎬 영화/v1.2']!.name, 'v1.2');
    });

    test('대소문자가 다르면 다른 폴더다(예전 폴더 합치기와 같은 규칙)', () {
      final (_, byPath) =
          buildFolderTree([(1, '여행/Japan'), (2, '여행/japan')], {1: 1, 2: 1});
      expect(byPath['여행']!.children.map((f) => f.name),
          ['Japan', 'japan']);
    });

    test('마지막 클립이 지워져 중간 폴더 컬렉션이 없어져도 하위 클립이 있으면 경로가 남는다', () {
      // '여행/일본' 컬렉션은 정리돼 없고 '여행/일본/오사카'만 남은 경우
      final (roots, byPath) =
          buildFolderTree([(1, '여행/일본/오사카')], {1: 1});
      expect(roots.single.name, '여행');
      expect(byPath['여행/일본']!.collectionIds, isEmpty);
      expect(byPath['여행/일본']!.totalCount, 1);
    });
  });
}
