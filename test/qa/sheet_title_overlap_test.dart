// 고르는 시트의 제목이 그 안의 줄과 겹치지 않는다(5차 494).
//
// 커뮤니티 글쓰기 시트는 단추도 '글쓰기', 제목도 '커뮤니티 글쓰기',
// 첫 줄도 '글쓰기'여서 같은 말이 세 겹이었다. 더보기의 '구독' 칸이
// 그 안의 '구독' 줄과 겹치던 것(873103c8)과 같은 결함이다.
//
// 여러 가지 가운데 하나를 고르는 시트는 '무엇을 …할까요?'로 묻는다.
// 보관함의 '+' 시트가 그렇게 하고 백업 고르기도 그렇다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _code(String path) => File(path)
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('커뮤니티 글쓰기 시트는 제 안의 줄과 겹치는 제목을 쓰지 않는다', () {
    final code = _code('lib/features/community/shell/presentation/'
        'sections/community_shell_write_sheet.dart');
    expect(code, contains("'무엇을 올릴까요?'"));
    expect(code.contains("'커뮤니티 글쓰기'"), isFalse);
    // 고르는 줄 넷은 그대로다.
    for (final option in ['글쓰기', '문장 공유하기', '질문하기', '투표 만들기']) {
      expect(code, contains("title: '$option'"), reason: option);
    }
  });

  test('고르는 시트들이 같은 꼴로 묻는다', () {
    const sheets = [
      'lib/features/community/shell/presentation/sections/community_shell_write_sheet.dart',
      'lib/features/collection/shell/presentation/collection_shell_screen.dart',
      'lib/features/settings/more/presentation/widgets/backup_parts_sheet.dart',
    ];
    for (final path in sheets) {
      expect(_code(path), contains('무엇을 '), reason: path);
    }
  });
}
