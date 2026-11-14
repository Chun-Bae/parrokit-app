// 백업 복원이 압축 안 경로를 그대로 믿지 않는지(5차).
//
// 백업 zip은 사용자가 고른 파일이라 어떤 이름이든 올 수 있다. 이름이 '../'로
// 시작하면 앱 폴더 밖에 파일을 쓸 수 있었다.
import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/infrastructure/services/backup_service.dart';
import 'package:path/path.dart' as p;

void main() {
  const root = '/tmp/restore_tmp';

  test('묶음 안 경로는 그대로 풀 자리를 돌려준다', () {
    expect(safeExtractPath(root, 'manifest.json'),
        p.normalize(p.join(root, 'manifest.json')));
    expect(safeExtractPath(root, 'media/clip.mp4'),
        p.normalize(p.join(root, 'media/clip.mp4')));
    // 윈도우에서 만든 묶음의 백슬래시도 받는다.
    expect(safeExtractPath(root, r'media\clip.mp4'),
        p.normalize(p.join(root, 'media/clip.mp4')));
  });

  test('묶음 밖으로 나가는 이름은 거부한다', () {
    for (final name in [
      '../evil.txt',
      'media/../../evil.txt',
      '..',
      '../',
      r'..\evil.txt',
    ]) {
      expect(safeExtractPath(root, name), isNull, reason: name);
    }
  });

  test('절대 경로와 빈 이름도 거부한다', () {
    expect(safeExtractPath(root, '/etc/passwd'), isNull);
    expect(safeExtractPath(root, ''), isNull);
    expect(safeExtractPath(root, '   '), isNull);
  });

  test('묶음 뿌리 자신도 쓸 자리로 보지 않는다', () {
    expect(safeExtractPath(root, '.'), isNull);
    expect(safeExtractPath(root, './'), isNull);
  });
}
