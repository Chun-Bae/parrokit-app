import 'dart:io';
import 'package:parrokit/data/models/post.dart';
import 'package:parrokit/features/community/shell/data/repositories/community_repository.dart';
import 'package:parrokit/features/community/shell/data/services/community_image_service.dart';
import 'package:parrokit/features/community/shell/domain/validators/post_validator.dart';

class EditPostUseCase {
  final CommunityRepository _repository;
  final CommunityImageService _imageService;

  EditPostUseCase(this._repository, this._imageService);

  Future<void> execute({
    required Post existingPost,
    required String title,
    required String content,
    required String category,
    required List<String> tags,
    required List<String> existingImageUrls,
    required List<File> newImageFiles,
    required String authorId,
    void Function(int current, int total, double progress)? onImageProgress,
  }) async {
    PostValidator.validateForCreate(
      title: title,
      content: content,
      category: category,
      tags: tags,
    );

    final deletedImageUrls = existingPost.imageUrls
        .where((url) => !existingImageUrls.contains(url))
        .toList();

    List<String> newUploadedUrls = [];
    for (int i = 0; i < newImageFiles.length; i++) {
      final file = newImageFiles[i];
      final url = await _imageService.uploadImageToStorage(
        file,
        userId: authorId,
        postId: existingPost.id,
        onProgress: (progress) {
          if (onImageProgress != null) {
            onImageProgress(i + 1, newImageFiles.length, progress);
          }
        },
      );
      if (url != null) {
        newUploadedUrls.add(url);
      }
    }

    final finalImageUrls = [...existingImageUrls, ...newUploadedUrls];

    final updateData = {
      'title': title,
      'content': content,
      'category': category,
      'tags': tags,
      'hasImage': finalImageUrls.isNotEmpty,
      'imageUrls': finalImageUrls,
      'snippet': content.length > 50 ? '${content.substring(0, 50)}...' : content,
    };

    // 지울 이미지는 저장이 끝난 뒤에 지운다. 전에는 맨 먼저 지웠다.
    // 그래서 저장이 실패하면 사용자가 뺀 이미지는 이미 사라졌는데 글은
    // 그대로라, 글이 없는 주소를 가리키게 되고 되돌릴 방법도 없었다.
    // 새로 올린 이미지도 글을 못 쓰면 아무도 가리키지 않으니 치운다.
    try {
      await _repository.updatePost(existingPost.id, updateData);
    } catch (_) {
      await _imageService.deleteImagesQuietly(newUploadedUrls);
      rethrow;
    }

    await _imageService.deleteImagesQuietly(deletedImageUrls);
  }
}
