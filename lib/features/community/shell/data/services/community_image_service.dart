import 'dart:io';
import 'package:parrokit/core/infrastructure/services/cloud/user_file_storage.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';

class CommunityImageService {
  Future<String?> uploadImageToStorage(
    File imageFile, {
    required String userId,
    required String postId,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String path = 'users/$userId/posts/$postId/$fileName';

      final result = await UserFileStorage.instance.uploadFile(
        imageFile,
        path: path,
        contentType: 'image/jpeg',
        onProgress: onProgress == null
            ? null
            : (sent, total) => onProgress(total == 0 ? 0.0 : sent / total),
      );
      return result.url;
    } catch (e, stack) {
      // 전에는 debugPrint였다. 올리기가 실패하면 이 함수는 null을 돌려주고,
      // 호출부는 그 이미지만 빼고 글을 등록한다. 사용자에게도 아무 말이
      // 없으므로 배포 뒤에는 실패했다는 사실조차 알 수 없었다.
      AppLogger.e('[Community][Image] 업로드 실패', error: e, stackTrace: stack);
      return null;
    }
  }

  /// 올려 둔 이미지를 모두 지운다. 실패해도 던지지 않는다.
  ///
  /// 글 작성이 중간에 엎어졌을 때 이미 올라간 이미지를 치우는 용도다.
  /// 정리하다 또 넘어져서 원래 오류를 덮으면 안 되니 조용히 넘어간다.
  /// 하나씩 기다리지 않고 한꺼번에 보낸다. R2로 옮긴 뒤로 지우기가
  /// Cloud Function 호출이라, 사진 세 장짜리 글이면 왕복이 세 번이고
  /// 함수가 자고 있으면 첫 호출에만 20초가 걸린다. 글이 화면에서
  /// 사라지기까지 그만큼 멈춰 있었다(5차 511).
  Future<void> deleteImagesQuietly(Iterable<String> imageUrls) async {
    await Future.wait(imageUrls.map(deleteImageFromStorage));
  }

  Future<bool> deleteImageFromStorage(String imageUrl) async {
    // 올려 둔 이미지를 치우다 실패한 것이라 흐름을 막지 않는다. 서버가
    // 실패를 w로 남긴다.
    return UserFileStorage.instance.deleteQuietly(url: imageUrl);
  }
}
