import 'dart:io';
import 'package:parrokit/data/models/post.dart';
import 'package:parrokit/features/community/shell/data/repositories/community_repository.dart';
import 'package:parrokit/features/community/shell/data/services/community_image_service.dart';
import 'package:parrokit/features/community/shell/domain/validators/post_validator.dart';

class AddQuestionUseCase {
  final CommunityRepository _repository;
  final CommunityImageService _imageService;

  AddQuestionUseCase(this._repository, this._imageService);

  Future<void> execute({
    required String title,
    required String content,
    required String category,
    required String authorId,
    required String authorNickname,
    required int rewardCrackers,
    required DateTime expireAt,
    String? authorAvatarUrl,
    List<String> tags = const [],
    List<File> imageFiles = const [],
    void Function(int current, int total, double progress)? onImageProgress,
  }) async {
    PostValidator.validateForCreate(
      title: title,
      content: content,
      category: category,
      tags: tags,
    );

    final String postId = _repository.generatePostId();

    List<String> uploadedUrls = [];
    for (int i = 0; i < imageFiles.length; i++) {
      final file = imageFiles[i];
      final url = await _imageService.uploadImageToStorage(
        file,
        userId: authorId,
        postId: postId,
        onProgress: (progress) {
          if (onImageProgress != null) {
            onImageProgress(i + 1, imageFiles.length, progress);
          }
        },
      );
      if (url != null) {
        uploadedUrls.add(url);
      }
    }

    final newPost = Post(
      id: postId,
      postType: 'question',
      category: category,
      title: title,
      content: content,
      tags: tags,
      hasImage: uploadedUrls.isNotEmpty,
      imageUrls: uploadedUrls,
      authorId: authorId,
      authorNickname: authorNickname,
      authorAvatarUrl: authorAvatarUrl,
      snippet: content.length > 50 ? '${content.substring(0, 50)}...' : content,
      rewardCrackers: rewardCrackers,
      expireAt: expireAt,
      questionStatus: 'waiting',
    );

    // 글 저장이 엎어지면 방금 올린 이미지는 아무도 가리키지 않는다.
    // Storage에 남아 용량만 먹으므로 치우고 던진다. 질문 글은 크래커가
    // 모자라면 저장 트랜잭션이 거절하는데, 그게 드문 경우도 아니다.
    try {
      await _repository.addQuestion(newPost, authorId, rewardCrackers);
    } catch (_) {
      await _imageService.deleteImagesQuietly(uploadedUrls);
      rethrow;
    }
  }
}
