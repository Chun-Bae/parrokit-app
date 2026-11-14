// 커뮤니티에서 읽는 글은 bodyReading(보통 굵기)으로 그린다(5차).
//
// 스케일의 다른 역할은 모두 굵어서(w600~w900), 글 본문·댓글·답변을 그 역할로
// 그리면 화면 전체가 제목처럼 보였다. 본문을 그리는 자리에 굵은 역할이 다시
// 들어오면 여기서 걸린다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 글 내용을 그리는 Text의 첫 줄.
final _contentLine = RegExp(r'(\w+\.content|answer\.content)\s*,\s*$');

/// 긴 글에 쓰면 안 되는 굵은 역할.
final _boldRole = RegExp(r'texts\.(titleMedium|titleLarge|bodyLarge|bodyMedium)');

void main() {
  test('커뮤니티 글 내용은 굵은 역할로 그리지 않는다', () {
    final files = Directory('lib/features/community')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    final offenders = <String>[];
    for (final file in files) {
      // 글을 쓰는 화면(write)은 입력칸이라 여기서 보지 않는다.
      if (file.path.contains('_write_')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!_contentLine.hasMatch(lines[i].trim())) continue;
        final until = (i + 6 < lines.length) ? i + 6 : lines.length;
        final block = lines.sublist(i, until).join('\n');
        // 목록 카드의 미리보기(maxLines로 잘라 보여 주는 줄)는 읽는 글이
        // 아니라 요약이라 그대로 둔다.
        if (block.contains('maxLines')) continue;
        for (var j = i + 1; j < (i + 4 < lines.length ? i + 4 : lines.length); j++) {
          if (_boldRole.hasMatch(lines[j])) {
            offenders.add('${file.path}:${j + 1}  ${lines[j].trim()}');
          }
        }
      }
    }

    expect(offenders, isEmpty,
        reason: '긴 글은 context.texts.bodyReading으로 그리세요.');
  });
}
