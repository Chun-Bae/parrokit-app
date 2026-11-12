import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
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
      final Reference ref = FirebaseStorage.instance.ref().child(path);

      final UploadTask uploadTask = ref.putFile(imageFile);

      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final double progress = snapshot.totalBytes == 0
              ? 0.0
              : snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        });
      }

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
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
  Future<void> deleteImagesQuietly(Iterable<String> imageUrls) async {
    for (final url in imageUrls) {
      await deleteImageFromStorage(url);
    }
  }

  Future<bool> deleteImageFromStorage(String imageUrl) async {
    try {
      final Reference ref = FirebaseStorage.instance.refFromURL(imageUrl);
      await ref.delete();
      return true;
    } catch (e) {
      // 올려 둔 이미지를 치우다 실패한 것이라 흐름을 막지 않는다.
      // 파일만 남으므로 w로 남긴다.
      AppLogger.w('[Community][Image] 삭제 실패: $e');
      return false;
    }
  }
}
