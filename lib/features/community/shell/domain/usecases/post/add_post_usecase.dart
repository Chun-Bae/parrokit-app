import 'dart:io';
import 'package:parrokit/data/models/post.dart';
import 'package:parrokit/data/models/vote_option.dart';
import 'package:parrokit/features/community/shell/data/repositories/community_repository.dart';
import 'package:parrokit/features/community/shell/data/services/community_image_service.dart';
import 'package:parrokit/features/community/shell/domain/validators/post_validator.dart';

class AddPostUseCase {
  final CommunityRepository _repository;
  final CommunityImageService _imageService;

  AddPostUseCase(this._repository, this._imageService);

  Future<void> execute({
    required String title,
    required String content,
    required String category,
    String postType = 'board',
    required String authorId,
    required String authorNickname,
    String? authorAvatarUrl,
    List<String> tags = const [],
    List<File> imageFiles = const [],
    List<VoteOption>? voteOptions,
    DateTime? voteEndTime,
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
      postType: postType,
      category: category,
      title: title,
      content: content,
      tags: tags,
      hasImage: uploadedUrls.isNotEmpty,
      imageUrls: uploadedUrls,
      authorId: authorId,
      authorNickname: authorNickname,
      authorAvatarUrl: authorAvatarUrl,
      voteOptions: voteOptions,
      voteEndTime: voteEndTime,
      snippet: content.length > 50 ? '${content.substring(0, 50)}...' : content,
    );

    // 글 저장이 엎어지면 방금 올린 이미지는 아무도 가리키지 않는다.
    // Storage에 남아 용량만 먹으므로 치우고 던진다.
    try {
      await _repository.addPost(newPost);
    } catch (_) {
      await _imageService.deleteImagesQuietly(uploadedUrls);
      rethrow;
    }
  }
}
