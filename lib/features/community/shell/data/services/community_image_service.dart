import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

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
    } catch (e) {
      debugPrint('Error uploading image: $e');
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
      debugPrint('Error deleting image: $e');
      return false;
    }
  }
}
