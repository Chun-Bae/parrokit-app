import 'package:parrokit/features/community/shared/presentation/write_blocked_reason.dart';

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
      throw ArgumentError(writeNeedsTitleMessage);
    }
    if (content.trim().isEmpty) {
      throw ArgumentError(writeNeedsContentMessage);
    }
    if (category.trim().isEmpty) {
      throw ArgumentError(writeNeedsTopicMessage);
    }
    if (tags.length > maxTags) {
      throw ArgumentError(writeTooManyTagsMessage(maxTags));
    }
    if (tags.any((tag) => tag.length > maxTagLength)) {
      throw ArgumentError('태그는 $maxTagLength글자 이하로 적어 주세요.');
    }
  }
}
