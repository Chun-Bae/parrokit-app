// 나가기 확인 창의 말투(5차).
//
// 클립 편집만 '편집을 취소하시겠습니까? / 입력한 모든 내용이 삭제됩니다.'로
// 딱딱했다. 다른 나가기 확인(초안 버리기, 콘텐츠 제작 나가기)은 '~까요?'와
// '~어요'를 쓴다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _code(String path) => File(path)
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('나가기 확인 세 곳이 같은 말투를 쓴다', () {
    final sheets = [
      'lib/features/content-studio/captioning/presentation/widgets/exit_confirm_sheet.dart',
      'lib/features/content-studio/hub/presentation/widgets/content_studio_exit_confirm_sheet.dart',
      'lib/core/shared/widgets/draft_pop_scope.dart',
    ];
    for (final path in sheets) {
      final code = _code(path);
      for (final bad in ['하시겠습니까', '삭제됩니다', '입니다.']) {
        expect(code.contains(bad), isFalse, reason: '$path: $bad');
      }
      // 묻는 말은 '~까요?'로 끝난다.
      expect(code.contains('까요?'), isTrue, reason: path);
    }
  });
}
