import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/features/community/shell/domain/validators/post_validator.dart';

void main() {
  group('PostValidator.validateForCreate', () {
    test('정상적인 입력인 경우 예외가 발생하지 않는다', () {
      expect(
        () => PostValidator.validateForCreate(
          title: '정상 제목',
          content: '정상 내용',
          category: '자유',
          tags: ['태그1', '태그2'],
        ),
        returnsNormally,
      );
    });

    test('제목이 비어있으면 ArgumentError를 던진다', () {
      expect(
        () => PostValidator.validateForCreate(
          title: '   ',
          content: '정상 내용',
          category: '자유',
          tags: ['태그1'],
        ),
        throwsA(isA<ArgumentError>()
            .having((e) => e.message, 'message', '제목을 적어 주세요.')),
      );
    });

    test('내용이 비어있으면 ArgumentError를 던진다', () {
      expect(
        () => PostValidator.validateForCreate(
          title: '정상 제목',
          content: '',
          category: '자유',
          tags: ['태그1'],
        ),
        throwsA(isA<ArgumentError>()
            .having((e) => e.message, 'message', '내용을 적어 주세요.')),
      );
    });

    test('주제가 비어있으면 ArgumentError를 던진다', () {
      expect(
        () => PostValidator.validateForCreate(
          title: '정상 제목',
          content: '정상 내용',
          category: '',
          tags: ['태그1'],
        ),
        throwsA(isA<ArgumentError>()
            .having((e) => e.message, 'message', '주제를 골라 주세요.')),
      );
    });

    test('태그가 최대 개수를 초과하면 ArgumentError를 던진다', () {
      final tags =
          List.generate(PostValidator.maxTags + 1, (index) => '태그$index');
      expect(
        () => PostValidator.validateForCreate(
          title: '정상 제목',
          content: '정상 내용',
          category: '자유',
          tags: tags,
        ),
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message',
            '태그는 최대 ${PostValidator.maxTags}개까지만 등록할 수 있습니다.')),
      );
    });

    test('태그 길이가 최대 길이를 초과하면 ArgumentError를 던진다', () {
      final longTag = '가' * (PostValidator.maxTagLength + 1);
      expect(
        () => PostValidator.validateForCreate(
          title: '정상 제목',
          content: '정상 내용',
          category: '자유',
          tags: [longTag],
        ),
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message',
            '태그는 ${PostValidator.maxTagLength}글자 이하로 적어 주세요.')),
      );
    });
  });
}
