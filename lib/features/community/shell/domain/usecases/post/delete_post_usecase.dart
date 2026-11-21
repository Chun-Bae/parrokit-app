import 'package:parrokit/data/models/post.dart';
import 'package:parrokit/features/community/shell/data/repositories/community_repository.dart';
import 'package:parrokit/features/community/shell/data/services/community_image_service.dart';

class DeletePostUseCase {
  final CommunityRepository _repository;
  final CommunityImageService _imageService;

  DeletePostUseCase(this._repository, this._imageService);

  Future<void> execute(Post postToDelete) async {
    // 사진을 먼저 지운다. 글이 먼저 사라지면 지우다 끊겼을 때 아무도
    // 가리키지 않는 사진이 남는다. 다만 한 장씩 기다리지는 않는다(5차 511).
    if (postToDelete.hasImage) {
      await _imageService.deleteImagesQuietly(postToDelete.imageUrls);
    }

    await _repository.deletePost(postToDelete.id);
  }
}
