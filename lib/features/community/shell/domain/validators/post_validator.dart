class PostValidator {
  static const int maxTags = 20;
  static const int maxTagLength = 10;

  static void validateForCreate({
    required String title,
    required String content,
    required String category,
    required List<String> tags,
  }) {
    if (title.trim().isEmpty) {
      throw ArgumentError('제목을 적어 주세요.');
    }
    if (content.trim().isEmpty) {
      throw ArgumentError('내용을 적어 주세요.');
    }
    if (category.trim().isEmpty) {
      throw ArgumentError('주제를 골라 주세요.');
    }
    if (tags.length > maxTags) {
      throw ArgumentError('태그는 최대 $maxTags개까지만 등록할 수 있습니다.');
    }
    if (tags.any((tag) => tag.length > maxTagLength)) {
      throw ArgumentError('태그는 $maxTagLength글자 이하로 적어 주세요.');
    }
  }
}
