import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/community/shell/domain/validators/comment_validator.dart';

void main() {
  group('CommentValidator.validateForCreate', () {
    test('정상적인 내용인 경우 예외가 발생하지 않는다', () {
      expect(
        () => CommentValidator.validateForCreate('정상적인 댓글 내용입니다.'),
        returnsNormally,
      );
    });

    test('내용이 비어있으면 ArgumentError를 던진다', () {
      expect(
        () => CommentValidator.validateForCreate('   '),
        throwsA(isA<ArgumentError>()
            .having((e) => e.message, 'message', '댓글 내용을 입력해 주세요.')),
      );
    });
  });
}
