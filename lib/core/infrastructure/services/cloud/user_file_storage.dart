// 사용자 파일 저장소 인터페이스.
//
// 프로필 사진, 글 사진, 클립 영상·썸네일, 자동 자막 원본처럼 사용자가 올리는
// 파일은 전부 이 인터페이스로만 다룬다. 지금 구현은 Cloudflare R2
// (R2StorageService)다. 다른 저장소로 바꾸려면 구현체 하나 더 만들고
// [UserFileStorage.instance]만 갈아 끼우면 된다. 호출부는 구현체 이름을 모른다.
//
// 경로 규칙은 어느 구현이든 같다: users/{uid}/... 와 caption-inputs/{uid}/...
// 만 쓰고, 소유자 검사는 서버가 한다.

import 'dart:io';
import 'dart:typed_data';

import 'package:parrokit/core/infrastructure/services/cloud/r2_storage_service.dart';

/// 올리기 결과. [url]은 영구 공개 주소라 Firestore에 저장해도 된다.
class UploadedFile {
  const UploadedFile({
    required this.path,
    required this.url,
    required this.size,
  });

  final String path;
  final String url;
  final int size;
}

class UserFileStorageException implements Exception {
  const UserFileStorageException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

abstract interface class UserFileStorage {
  /// 앱 전체가 쓰는 구현. 테스트나 교체 시 바꿔 끼운다.
  static UserFileStorage instance = R2StorageService();

  Future<UploadedFile> uploadFile(
    File file, {
    required String path,
    String? contentType,
    void Function(int sent, int total)? onProgress,
  });

  Future<UploadedFile> uploadBytes(
    Uint8List bytes, {
    required String path,
    String? contentType,
    void Function(int sent, int total)? onProgress,
  });

  /// [url]이 있으면 그 주소로, 없으면 [path]로 서버에 읽기 주소를 물어 받는다.
  Future<void> downloadToFile({
    String? path,
    String? url,
    required File destination,
    void Function(int received, int total)? onProgress,
  });

  /// 지운다. 실패해도 던지지 않고 false. 저장소가 관리하지 않는 주소면 false.
  Future<bool> deleteQuietly({String? path, String? url});
}
