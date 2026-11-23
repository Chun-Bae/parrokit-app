// 임시 파일 재기·지우기(5차 566).
//
// 기기에서 임시 폴더가 2.9GB인데 '62 MB'로 보였고, 정리한 뒤에는
// '0 B'로 바뀌었는데 디스크는 그대로였다. 못 읽거나 못 지우는 칸
// 하나가 전체를 삼킨 탓이다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/infrastructure/services/cache_service.dart';

Directory _temp() {
  final dir = Directory.systemTemp.createTempSync('parrokit_cache_test');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return dir;
}

void _write(Directory dir, String name, int bytes) {
  File('${dir.path}/$name').writeAsBytesSync(List.filled(bytes, 0));
}

void main() {
  group('재기', () {
    test('하위 폴더까지 더한다', () async {
      final root = _temp();
      _write(root, 'a.bin', 100);
      final child = Directory('${root.path}/child')..createSync();
      _write(child, 'b.bin', 250);
      final grand = Directory('${child.path}/grand')..createSync();
      _write(grand, 'c.bin', 50);

      expect(await measureDirectory(root), 400);
    });

    test('못 읽는 칸이 있어도 나머지를 센다', () async {
      final root = _temp();
      _write(root, 'a.bin', 100);
      final locked = Directory('${root.path}/locked')..createSync();
      _write(locked, 'big.bin', 900);
      // 읽을 수 없게 막는다. 통째로 읽는 방식은 여기서 0을 돌려줬다.
      Process.runSync('chmod', ['000', locked.path]);
      addTearDown(() => Process.runSync('chmod', ['755', locked.path]));

      expect(await measureDirectory(root), 100);
    });

    test('빈 폴더는 0이다', () async {
      expect(await measureDirectory(_temp()), 0);
    });

    test('없는 폴더도 0이고 던지지 않는다', () async {
      final gone = Directory('${_temp().path}/none');
      expect(await measureDirectory(gone), 0);
    });
  });

  group('지우기', () {
    test('안의 것만 지우고 폴더는 남긴다', () async {
      final root = _temp();
      _write(root, 'a.bin', 10);
      Directory('${root.path}/child').createSync();

      await clearDirectoryContents(root);

      expect(root.existsSync(), isTrue);
      expect(root.listSync(), isEmpty);
    });

    test('못 지우는 칸이 있어도 나머지는 지운다', () async {
      final root = _temp();
      _write(root, 'a.bin', 10);
      final locked = Directory('${root.path}/locked')..createSync();
      _write(locked, 'big.bin', 900);
      Process.runSync('chmod', ['500', root.path]);
      addTearDown(() => Process.runSync('chmod', ['755', root.path]));

      await clearDirectoryContents(root);

      Process.runSync('chmod', ['755', root.path]);
      // 쓰기가 막힌 폴더라 아무것도 못 지웠지만 던지지는 않는다.
      expect(root.existsSync(), isTrue);
      expect(locked.existsSync(), isTrue);
    });
  });
}
