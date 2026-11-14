// 보관함으로 들어가는 말(5차).
//
// 홈에서는 '공유 문장'이라 부르는 자리를 보관함은 '둘러보기'라고만 해서,
// 홈의 '전체 보기'로 오면 다른 곳처럼 보였다. 추가 시트 제목 '새 학습 재료'의
// '재료'도 앱의 다른 곳에서 쓰지 않는 말이었다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _code(String path) => File(path)
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('보관함 공유 문장 자리가 홈과 같은 말을 쓴다', () {
    final library = _code(
      'lib/features/collection/shell/presentation/widgets/sentence_collection_preview.dart',
    );
    expect(library, contains("Text('공유 문장 둘러보기'"));

    final home = _code(
      'lib/features/home/dashboard/presentation/widgets/trending_sentences_preview.dart',
    );
    expect(home, contains("'공유 문장'"));
  });

  test('추가 시트 제목에 "재료" 같은 말을 쓰지 않는다', () {
    final shell = _code(
      'lib/features/collection/shell/presentation/collection_shell_screen.dart',
    );
    expect(shell.contains('새 학습 재료'), isFalse);
    expect(shell, contains("'무엇을 추가할까요?'"));
  });
}
