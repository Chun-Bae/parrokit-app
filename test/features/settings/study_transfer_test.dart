// 문장·단어를 설정에서도 주고받을 수 있어야 한다(사용자 요청 2026-11-17).
//
// 전에는 보관함 문장 탭의 ⋮ 메뉴에만 있었고 단어는 아예 길이 없었다.
// 백업은 클립과 영상까지 담는 큰 일이라, 글만 주고받고 싶을 때 쓸 자리가
// 따로 필요하다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/content/study_file_name.dart';

String _code(String path) => File(path)
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('파일 이름이 백업·음성과 같은 꼴이다', () {
    expect(studyFileName(DateTime(2026, 11, 17, 12, 44, 5)),
        'Parrokit_문장단어_20261117_124405.json');
  });

  test('더보기 데이터 칸에 주고받기 줄이 있다', () {
    final code =
        _code('lib/features/settings/more/presentation/sections/data_section.dart');
    expect(code, contains("title: '문장·단어 주고받기'"));
    expect(code, contains('_openStudyTransferSheet'));
  });

  test('내보내기와 불러오기 둘 다 있다', () {
    final code =
        _code('lib/features/settings/more/presentation/sections/data_section.dart');
    expect(code, contains("ValueKey('study-export')"));
    expect(code, contains("ValueKey('study-import')"));
    // 백업과 같은 글귀 모음을 쓴다(문장 N개 · 단어 N개).
    expect(code, contains('studyRestoreSummary(count)'));
    // 이미 있는 것을 건너뛴다는 점을 미리 적는다.
    expect(code, contains('건너뛰어요'));
  });

  test('고르지 않고 닫으면 아무 일도 하지 않는다', () {
    final code =
        _code('lib/features/settings/more/presentation/sections/data_section.dart');
    expect(code, contains('if (path == null) return;'));
    expect(code, contains('if (choice == null || !mounted) return;'));
  });
}
