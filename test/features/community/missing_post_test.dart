// 지워졌거나 못 여는 글은 가짜 글로 그리지 않는다(5차).
//
// 전에는 제목이 '게시글을 찾을 수 없습니다.'인 Post를 만들어 보통 글처럼
// 그렸다. 공감·스크랩·댓글 입력칸이 그대로 살아 있어서, 없는 글에 댓글을
// 쓰려다 실패했다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/community/board/presentation/missing_post_notice.dart';

void main() {
  test('안내는 앱 말투로 적는다', () {
    expect(missingPostTitle, '글을 볼 수 없어요');
    for (final line in [
      missingPostTitle,
      missingPostDescription,
      missingPostBackLabel,
    ]) {
      expect(line.contains('습니다'), isFalse, reason: line);
    }
  });

  test('상세 화면이 없는 글을 가짜 글로 만들지 않는다', () {
    // 주석은 빼고 실제 코드만 본다(왜 바꿨는지 주석에는 옛 문구가 남는다).
    final source = File(
      'lib/features/community/board/presentation/board_view_screen.dart',
    )
        .readAsLinesSync()
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');
    expect(source.contains('게시글을 찾을 수 없습니다.'), isFalse);
    expect(source.contains("title: '알 수 없음'"), isFalse);
    // 글을 못 찾으면 빈 화면을 그린다.
    expect(source.contains('missingPostTitle'), isTrue);
  });
}
