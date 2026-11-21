// UserFileStorage의 Cloudflare R2 구현.
//
// 앱은 R2에 직접 붙지 않는다. Functions(r2SignUpload 등)가 로그인한 사용자를
// 확인하고 자기 폴더 안 경로에만 presigned URL을 내준다. 여기서는 그 URL로
// HTTP PUT/GET만 한다. 전에 FirebaseStorage.instance를 직접 쓰던 자리를
// 전부 이 서비스로 바꿨다.

import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:dio/dio.dart';
import 'package:parrokit/core/infrastructure/services/cloud/user_file_storage.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';

class R2StorageService implements UserFileStorage {
  R2StorageService({FirebaseFunctions? functions, Dio? dio})
      : _functions = functions ?? FirebaseFunctions.instance,
        _dio = dio ?? Dio();

  final FirebaseFunctions _functions;
  final Dio _dio;

  @override
  Future<UploadedFile> uploadFile(
    File file, {
    required String path,
    String? contentType,
    void Function(int sent, int total)? onProgress,
  }) async {
    final size = await file.length();
    return _upload(
      path: path,
      contentType: contentType,
      size: size,
      body: file.openRead(),
      onProgress: onProgress,
      timeout: const Duration(minutes: 30),
    );
  }

  @override
  Future<UploadedFile> uploadBytes(
    Uint8List bytes, {
    required String path,
    String? contentType,
    void Function(int sent, int total)? onProgress,
  }) {
    return _upload(
      path: path,
      contentType: contentType,
      size: bytes.length,
      body: Stream.value(bytes),
      onProgress: onProgress,
      timeout: const Duration(minutes: 10),
    );
  }

  Future<UploadedFile> _upload({
    required String path,
    required String? contentType,
    required int size,
    required Stream<List<int>> body,
    required void Function(int sent, int total)? onProgress,
    required Duration timeout,
  }) async {
    final resolvedType = contentType ?? 'application/octet-stream';
    final signed = await _call('r2SignUpload', {
      'path': path,
      'contentType': resolvedType,
      'size': size,
    });
    final uploadUrl = signed['uploadUrl'] as String?;
    if (uploadUrl == null || uploadUrl.isEmpty) {
      throw const UserFileStorageException('업로드 주소를 받지 못했어요.');
    }
    // 서명에 Content-Type이 들어가므로 서버가 돌려준 값을 그대로 보낸다.
    final signedType = signed['contentType'] as String? ?? resolvedType;

    try {
      final response = await _dio.put<void>(
        uploadUrl,
        data: body,
        onSendProgress: onProgress,
        options: Options(
          headers: {
            Headers.contentTypeHeader: signedType,
            Headers.contentLengthHeader: size,
          },
          sendTimeout: timeout,
          receiveTimeout: const Duration(minutes: 2),
          responseType: ResponseType.plain,
        ),
      );
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        throw UserFileStorageException('업로드 실패 (HTTP $status)');
      }
    } on DioException catch (e, st) {
      AppLogger.e('[R2] upload failed path=$path', error: e, stackTrace: st);
      throw UserFileStorageException(
        e.type == DioExceptionType.connectionError ||
                e.type == DioExceptionType.sendTimeout
            ? '네트워크가 불안정해서 올리지 못했어요.'
            : '파일을 올리지 못했어요.',
        code: e.type.name,
      );
    }

    final finished = await _call('r2FinishUpload', {'path': path});
    final url = finished['publicUrl'] as String?;
    if (url == null || url.isEmpty) {
      throw const UserFileStorageException('올린 파일 주소를 받지 못했어요.');
    }
    return UploadedFile(
      path: finished['path'] as String? ?? path,
      url: url,
      size: (finished['size'] as num?)?.toInt() ?? size,
    );
  }

  /// 옛 Firebase Storage 주소도 서버가 알아서 서명 주소로 바꿔 준다.
  @override
  Future<void> downloadToFile({
    String? path,
    String? url,
    required File destination,
    void Function(int received, int total)? onProgress,
  }) async {
    String? resolvedUrl = url;
    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      if (path == null || path.isEmpty) {
        throw const UserFileStorageException('서버 파일 경로를 찾을 수 없습니다.');
      }
      final signed = await _call('r2SignDownload', {'path': path});
      resolvedUrl = signed['url'] as String?;
      if (resolvedUrl == null || resolvedUrl.isEmpty) {
        throw const UserFileStorageException('파일 주소를 받지 못했어요.');
      }
    }

    await destination.parent.create(recursive: true);
    final tempFile = File('${destination.path}.part');
    try {
      await _dio.download(
        resolvedUrl,
        tempFile.path,
        onReceiveProgress: onProgress,
        options: Options(receiveTimeout: const Duration(minutes: 30)),
      );
    } on DioException catch (e, st) {
      await tempFile.delete().catchError((_) => tempFile);
      final status = e.response?.statusCode;
      // 공개 주소가 죽었거나(옛 토큰 주소 등) 403/404면 서버에 서명 주소를
      // 한 번 더 묻는다.
      if ((status == 403 || status == 404) &&
          url != null &&
          path != null &&
          path.isNotEmpty) {
        AppLogger.w('[R2] download $status, retry via signed url path=$path');
        return downloadToFile(
          path: path,
          destination: destination,
          onProgress: onProgress,
        );
      }
      AppLogger.e('[R2] download failed', error: e, stackTrace: st);
      throw const UserFileStorageException('파일을 받지 못했어요.');
    }
    if (await destination.exists()) {
      await destination.delete();
    }
    await tempFile.rename(destination.path);
  }

  @override
  Future<bool> deleteQuietly({String? path, String? url}) async {
    if ((path == null || path.isEmpty) && (url == null || url.isEmpty)) {
      return false;
    }
    try {
      final result = await _call('r2DeleteObject', {
        if (path != null && path.isNotEmpty) 'path': path,
        if (url != null && url.isNotEmpty) 'url': url,
      });
      return result['deleted'] == true;
    } catch (e) {
      AppLogger.w('[R2] delete failed path=$path url=$url: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    try {
      final result = await _functions
          .httpsCallable(
            name,
            options: HttpsCallableOptions(timeout: const Duration(minutes: 2)),
          )
          .call<dynamic>(data);
      final raw = result.data;
      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
      return const {};
    } on FirebaseFunctionsException catch (e) {
      final message = e.message?.trim();
      throw UserFileStorageException(
        message != null && message.isNotEmpty && message != 'INTERNAL'
            ? message
            : switch (e.code) {
                'unauthenticated' => '로그인이 필요해요.',
                'resource-exhausted' => '서버 저장 공간이 모자라요.',
                'permission-denied' => '내 파일만 다룰 수 있어요.',
                _ => '서버 저장소 요청에 실패했어요.',
              },
        code: e.code,
      );
    }
  }
}
