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
  test('클립 편집 글귀가 앱 말투를 쓴다', () {
    // '입력해주세요.'·'삭제'가 섞여 있었다(5차).
    final strings = _code(
      'lib/features/content-studio/captioning/data/constants/edit_strings.dart',
    );
    expect(strings.contains('입력해주세요'), isFalse);
    expect(strings.contains("'구간 삭제'"), isFalse);
    expect(strings, contains('적어 주세요'));

    final screen = _code(
      'lib/features/content-studio/captioning/presentation/widgets/picked_state.dart',
    );
    // '확장자'는 개발 용어라 쓰지 않는다.
    expect(screen.contains("Text('확장자'"), isFalse);
    expect(screen, contains("Text('영상 형식'"));
  });

  test('영상 설정 버튼이 누르면 열리는 창과 같은 말을 쓴다', () {
    final screen = _code(
      'lib/features/content-studio/captioning/presentation/widgets/picked_state.dart',
    );
    // 버튼 '다시 선택' → 창 '영상 다시 고르기'로 달랐다(5차).
    expect(screen.contains("title: '다시 선택'"), isFalse);
    expect(screen, contains("title: '영상 다시 고르기'"));
    // 지우는 버튼은 무엇을 지우는지 밝힌다(확인 창도 '영상 지우기').
    expect(screen, contains("title: '영상 지우기'"));
    // '배속'·'스킵'은 플레이어·조작 줄이 쓰지 않는 말이다.
    expect(screen.contains("title: '배속'"), isFalse);
    expect(screen.contains('스킵'), isFalse);
  });

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
