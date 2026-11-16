class CommentValidator {
  static void validateForCreate(String content) {
    if (content.trim().isEmpty) {
      throw ArgumentError('댓글 내용을 입력해 주세요.');
    }
  }
}
