import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'dart:typed_data';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:parrokit/core/shared/utils/app_logger.dart';

typedef GoogleDriveProgressCallback = void Function(
  int current,
  int total,
  String message,
);

class GoogleDriveUploadResult {
  GoogleDriveUploadResult({
    required this.fileId,
    required this.fileName,
    required this.folderId,
    required this.accountKey,
    this.webViewLink,
    this.webContentLink,
  });

  final String fileId;
  final String fileName;
  final String folderId;
  final String accountKey;
  final String? webViewLink;
  final String? webContentLink;
}

class GoogleDriveJsonUploadResult {
  GoogleDriveJsonUploadResult({
    required this.fileId,
    required this.fileName,
    required this.folderId,
    required this.accountKey,
  });

  final String fileId;
  final String fileName;
  final String folderId;
  final String accountKey;
}

class GoogleDriveStorageQuota {
  GoogleDriveStorageQuota({
    required this.usedBytes,
    this.limitBytes,
  });

  final int usedBytes;
  final int? limitBytes;
}

class GoogleDriveStorageService {
  static const String _driveScope =
      'https://www.googleapis.com/auth/drive.file';
  static const String _folderName = 'Parrokit';
  static const String _folderCacheKeyPrefix = 'google_drive_folder_id';

  GoogleDriveStorageService({GoogleSignIn? googleSignIn})
      : _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: const [_driveScope],
            );

  final GoogleSignIn _googleSignIn;

  Future<GoogleSignInAccount?> connect() async {
    final current = await _googleSignIn.signInSilently(suppressErrors: true);
    if (current != null) return current;
    return _googleSignIn.signIn();
  }

  Future<bool> hasConnectedAccount() async {
    final current = await _googleSignIn.signInSilently(suppressErrors: true);
    return current != null;
  }

  Future<void> disconnect() async {
    await _googleSignIn.signOut();
  }

  Future<String?> currentAccountKey() async {
    final account = await _googleSignIn.signInSilently(suppressErrors: true);
    return account == null ? null : _accountKey(account);
  }

  Future<GoogleDriveStorageQuota?> fetchStorageQuota() async {
    final account = await _googleSignIn.signInSilently(suppressErrors: true);
    if (account == null) {
      return null;
    }

    final headers = await _authorizationHeaders(account);
    final client = HttpClient();
    try {
      final uri = Uri.https(
        'www.googleapis.com',
        '/drive/v3/about',
        const {'fields': 'storageQuota'},
      );
      final request = await client.getUrl(uri);
      headers.forEach((key, value) {
        request.headers.set(key, value);
      });

      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await utf8.decodeStream(response);
        throw StateError(
          'Google Drive 저장 용량 조회 실패: ${response.statusCode} $body',
        );
      }

      final body = await utf8.decodeStream(response);
      final data = _asMap(body);
      final quota = data['storageQuota'];
      if (quota is! Map<String, dynamic>) return null;

      final usedBytes = int.tryParse('${quota['usageInDrive'] ?? 0}') ?? 0;
      final limitRaw = quota['limit'];
      final limitBytes = limitRaw == null ? null : int.tryParse('$limitRaw');
      return GoogleDriveStorageQuota(
        usedBytes: usedBytes,
        limitBytes: limitBytes,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<GoogleDriveUploadResult> uploadClipFile({
    required File file,
    required String fileName,
    required String clipId,
    required String storagePath,
    required String title,
    required int storageBytes,
    required int durationMs,
    required String remoteDocId,
    required String ownerScope,
    GoogleDriveProgressCallback? onProgress,
  }) async {
    final account = await connect();
    if (account == null) {
      throw StateError('Google Drive 연결이 필요합니다.');
    }

    final headers = await _authorizationHeaders(account);
    final accountKey = _accountKey(account);
    final folderSegments = _folderSegmentsForStoragePath(storagePath);
    final folderId = await _ensureFolderPath(
      account,
      headers,
      folderSegments,
    );
    onProgress?.call(0, 0, 'Google Drive 연결 확인 중');

    final uploadUri = Uri.https(
      'www.googleapis.com',
      '/upload/drive/v3/files',
      const {
        'uploadType': 'multipart',
        'fields': 'id,name,webViewLink,webContentLink,parents',
      },
    );
    final boundary =
        'parrokit-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';
    final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
    final totalBytes = await file.length();

    final metadata = <String, dynamic>{
      'name': fileName,
      'parents': [folderId],
      'appProperties': <String, String>{
        'clipId': clipId,
        'remoteDocId': remoteDocId,
        'title': title,
        'storageMode': 'gdrive',
        'provider': 'gdrive',
        'ownerScope': ownerScope,
        'ownerKey': accountKey,
        'storageBytes': storageBytes.toString(),
        'durationMs': durationMs.toString(),
        'storagePath': storagePath,
      },
    };

    final client = HttpClient();
    try {
      AppLogger.i(
        '[GoogleDrive][Upload] start file=${_maskFileName(fileName)} bytes=$totalBytes',
      );
      onProgress?.call(0, totalBytes, 'Google Drive에 저장하는 중');
      final request = await client.postUrl(uploadUri);
      headers.forEach((key, value) {
        request.headers.set(key, value);
      });
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'multipart/related; boundary="$boundary"',
      );
      request.add(_utf8Bytes('--$boundary\r\n'));
      request.add(
        _utf8Bytes('Content-Type: application/json; charset=UTF-8\r\n\r\n'),
      );
      request.add(_utf8Bytes('${jsonEncode(metadata)}\r\n'));
      request.add(_utf8Bytes('--$boundary\r\n'));
      request.add(_utf8Bytes('Content-Type: $mimeType\r\n\r\n'));
      var sentBytes = 0;
      await for (final chunk in file.openRead()) {
        request.add(chunk);
        sentBytes += chunk.length;
        onProgress?.call(sentBytes, totalBytes, 'Google Drive에 올리는 중');
      }
      request.add(_utf8Bytes('\r\n--$boundary--'));
      final response = await request.close();
      final responseBody = await utf8.decodeStream(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          'Google Drive 업로드 실패: ${response.statusCode} $responseBody',
        );
      }

      final data = _asMap(responseBody);
      final result = GoogleDriveUploadResult(
        fileId: data['id'] as String? ?? '',
        fileName: data['name'] as String? ?? fileName,
        folderId: folderId,
        accountKey: accountKey,
        webViewLink: data['webViewLink'] as String?,
        webContentLink: data['webContentLink'] as String?,
      );

      if (result.fileId.isEmpty) {
        throw StateError('Google Drive 파일 ID를 받지 못했습니다.');
      }

      onProgress?.call(1, 1, 'Google Drive 저장 완료');
      AppLogger.i(
        '[GoogleDrive][Upload] success file=${_maskFileName(fileName)} fileId=${result.fileId} bytes=$sentBytes',
      );
      return result;
    } finally {
      client.close(force: true);
    }
  }

  Future<File> downloadClipFile({
    required String fileId,
    required File destination,
    GoogleDriveProgressCallback? onProgress,
  }) async {
    final account = await connect();
    if (account == null) {
      throw StateError('Google Drive 연결이 필요합니다.');
    }

    final headers = await _authorizationHeaders(account);
    final client = http.Client();
    try {
      AppLogger.i('[GoogleDrive][Download] start fileId=$fileId');
      final downloadUri = Uri.https(
        'www.googleapis.com',
        '/drive/v3/files/$fileId',
        const {'alt': 'media'},
      );
      final request = http.Request('GET', downloadUri);
      request.headers.addAll(headers);

      onProgress?.call(0, 0, 'Google Drive에서 내려받는 중');
      final response = await client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.stream.bytesToString();
        throw StateError(
          'Google Drive 다운로드 실패: ${response.statusCode} $body',
        );
      }

      await destination.parent.create(recursive: true);
      final sink = destination.openWrite();
      try {
        await response.stream.pipe(sink);
      } finally {
        await sink.close();
      }
      onProgress?.call(1, 1, 'Google Drive 다운로드 완료');
      AppLogger.i(
        '[GoogleDrive][Download] success fileId=$fileId path=${destination.path}',
      );
      return destination;
    } finally {
      client.close();
    }
  }

  Future<GoogleDriveJsonUploadResult> upsertJsonFile({
    required String storagePath,
    required Map<String, dynamic> content,
    Map<String, String>? appProperties,
  }) async {
    AppLogger.i('[GoogleDrive][Json] upsert-start path=$storagePath');
    final account = await connect();
    if (account == null) {
      throw StateError('Google Drive 연결이 필요합니다.');
    }

    final headers = await _authorizationHeaders(account);
    final accountKey = _accountKey(account);
    final folderSegments = _folderSegmentsForStoragePath(storagePath);
    final folderId = await _ensureFolderPath(
      account,
      headers,
      folderSegments,
    );
    final fileName = _fileNameForStoragePath(storagePath);
    final existingFileId = await _findFileByName(
      parentId: folderId,
      fileName: fileName,
      headers: headers,
    );

    final metadata = <String, dynamic>{
      'name': fileName,
      'mimeType': 'application/json',
      if (existingFileId == null) 'parents': [folderId],
      if (appProperties != null) 'appProperties': appProperties,
    };
    final bodyBytes = _utf8Bytes(
      const JsonEncoder.withIndent('  ').convert(content),
    );

    final data = await _uploadMultipartBytes(
      method: existingFileId == null ? 'POST' : 'PATCH',
      fileId: existingFileId,
      metadata: metadata,
      bodyBytes: bodyBytes,
      mimeType: 'application/json; charset=UTF-8',
      headers: headers,
    );
    final fileId = data['id'] as String? ?? existingFileId ?? '';
    if (fileId.isEmpty) {
      throw StateError('Google Drive JSON 파일 ID를 받지 못했습니다.');
    }

    AppLogger.i(
      '[GoogleDrive][Json] upsert-success path=$storagePath fileId=$fileId',
    );
    return GoogleDriveJsonUploadResult(
      fileId: fileId,
      fileName: data['name'] as String? ?? fileName,
      folderId: folderId,
      accountKey: accountKey,
    );
  }

  Future<void> deleteFile(String fileId) async {
    final account = await connect();
    if (account == null) {
      throw StateError('Google Drive 연결이 필요합니다.');
    }

    final headers = await _authorizationHeaders(account);
    final client = http.Client();
    try {
      final deleteUri = Uri.https(
        'www.googleapis.com',
        '/drive/v3/files/$fileId',
      );
      final request = http.Request('DELETE', deleteUri);
      request.headers.addAll(headers);

      final response = await client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.stream.bytesToString();
        if (response.statusCode == 404) {
          AppLogger.w(
            '[GoogleDrive][Delete] not-found fileId=$fileId body=$body',
          );
          return;
        }
        throw StateError(
          'Google Drive 삭제 실패: ${response.statusCode} $body',
        );
      }
      AppLogger.i('[GoogleDrive][Delete] success fileId=$fileId');
    } finally {
      client.close();
    }
  }

  /// Parrokit/clips/ 아래의 클립 폴더 목록을 (remoteDocId, folderId) 쌍으로
  /// 반환합니다. 각 폴더 이름이 곧 그 클립의 remoteDocId입니다.
  Future<List<(String, String)>> listClipFolders() async {
    final account = await connect();
    if (account == null) {
      AppLogger.w('[GoogleDrive][List] clip-folders no-account');
      return const [];
    }

    final headers = await _authorizationHeaders(account);
    final clipsFolderId =
        await _ensureFolderPath(account, headers, const ['clips']);
    final result =
        await _listChildFolders(parentId: clipsFolderId, headers: headers);
    AppLogger.i(
      '[GoogleDrive][List] clip-folders account=${_maskAccount(account)} '
      'clipsFolderId=$clipsFolderId count=${result.length}',
    );
    return result;
  }

  /// Parrokit/[folderSegments] 경로 바로 아래 파일들을 이름→fileId 맵으로
  /// 반환합니다. `listClipFolders`가 클립 하위 "폴더" 목록을 보는 것과 달리,
  /// 이건 groups/collections처럼 flat하게 저장된 "파일" 목록을 볼 때 씁니다.
  Future<Map<String, String>> listFilesInFolderPath(
    List<String> folderSegments,
  ) async {
    final account = await connect();
    if (account == null) return const {};

    final headers = await _authorizationHeaders(account);
    final folderId = await _ensureFolderPath(account, headers, folderSegments);
    return listFilesInFolder(folderId);
  }

  /// [folderId] 폴더 바로 아래 파일들을 이름→fileId 맵으로 반환합니다.
  Future<Map<String, String>> listFilesInFolder(String folderId) async {
    final account = await connect();
    if (account == null) return const {};

    final headers = await _authorizationHeaders(account);
    final client = http.Client();
    try {
      final query = "trashed = false and '$folderId' in parents";
      final uri = Uri.https('www.googleapis.com', '/drive/v3/files').replace(
        queryParameters: {
          'q': query,
          'fields': 'files(id,name)',
          'pageSize': '100',
        },
      );
      final response = await client.get(uri, headers: headers);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        AppLogger.w(
          '[GoogleDrive][List] files-in-folder failed folderId=$folderId '
          'status=${response.statusCode} body=${response.body}',
        );
        return const {};
      }
      final files = _asMap(response.body)['files'];
      if (files is! List) return const {};
      final map = {
        for (final f in files.whereType<Map<String, dynamic>>())
          if (f['name'] is String && f['id'] is String)
            f['name'] as String: f['id'] as String,
      };
      AppLogger.d(
        '[GoogleDrive][List] files-in-folder folderId=$folderId names=${map.keys.toList()}',
      );
      return map;
    } finally {
      client.close();
    }
  }

  /// 파일 ID의 내용을 텍스트로 내려받습니다 (metadata.json 같은 작은 파일용).
  Future<String?> downloadFileContent(String fileId) async {
    final account = await connect();
    if (account == null) return null;

    final headers = await _authorizationHeaders(account);
    final client = http.Client();
    try {
      final uri = Uri.https(
        'www.googleapis.com',
        '/drive/v3/files/$fileId',
        const {'alt': 'media'},
      );
      final response = await client.get(uri, headers: headers);
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      return response.body;
    } finally {
      client.close();
    }
  }

  Future<List<(String, String)>> _listChildFolders({
    required String parentId,
    required Map<String, String> headers,
  }) async {
    final client = http.Client();
    try {
      final query = [
        "mimeType = 'application/vnd.google-apps.folder'",
        "trashed = false",
        "'$parentId' in parents",
      ].join(' and ');
      final uri = Uri.https('www.googleapis.com', '/drive/v3/files').replace(
        queryParameters: {
          'q': query,
          'fields': 'files(id,name)',
          'pageSize': '1000',
        },
      );
      final response = await client.get(uri, headers: headers);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        AppLogger.w(
          '[GoogleDrive][List] child-folders failed parentId=$parentId '
          'status=${response.statusCode} body=${response.body}',
        );
        return const [];
      }
      final files = _asMap(response.body)['files'];
      if (files is! List) return const [];
      return files
          .whereType<Map<String, dynamic>>()
          .where((f) => f['name'] is String && f['id'] is String)
          .map((f) => (f['name'] as String, f['id'] as String))
          .toList();
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>?> fetchFileMetadata(String fileId) async {
    final account = await connect();
    if (account == null) {
      throw StateError('Google Drive 연결이 필요합니다.');
    }

    final headers = await _authorizationHeaders(account);
    final client = http.Client();
    try {
      final uri = Uri.https(
        'www.googleapis.com',
        '/drive/v3/files/$fileId',
        const {
          'fields': 'id,name,mimeType,trashed,parents',
        },
      );
      final response = await client.get(uri, headers: headers);
      if (response.statusCode == 404) return null;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          'Google Drive 메타데이터 조회 실패: ${response.statusCode} ${response.body}',
        );
      }
      return _asMap(response.body);
    } finally {
      client.close();
    }
  }

  Future<String> _ensureFolderPath(
    GoogleSignInAccount account,
    Map<String, String> headers,
    List<String> folderSegments,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    var currentParentId = await _ensureRootFolder(account, headers, prefs);
    if (folderSegments.isEmpty) {
      return currentParentId;
    }

    var currentPath = <String>[_folderName];
    for (final segment in folderSegments) {
      currentPath = [...currentPath, segment];
      currentParentId = await _ensureChildFolder(
        account: account,
        headers: headers,
        prefs: prefs,
        parentId: currentParentId,
        folderName: segment,
        folderPath: currentPath,
      );
    }
    return currentParentId;
  }

  List<String> _folderSegmentsForStoragePath(String storagePath) {
    final segments =
        storagePath.split('/').where((segment) => segment.isNotEmpty).toList();
    if (segments.length <= 1) {
      return const [];
    }
    return segments.sublist(0, segments.length - 1);
  }

  Future<String> _ensureRootFolder(
    GoogleSignInAccount account,
    Map<String, String> headers,
    SharedPreferences prefs,
  ) async {
    final cacheKey = '${_folderCacheKeyPrefix}_${_accountKey(account)}_root';
    final cachedFolderId = prefs.getString(cacheKey);
    if (cachedFolderId != null && cachedFolderId.isNotEmpty) {
      final metadata = await fetchFileMetadata(cachedFolderId);
      if (metadata != null &&
          metadata['mimeType'] == 'application/vnd.google-apps.folder' &&
          metadata['trashed'] != true) {
        return cachedFolderId;
      }
    }

    final folderId = await _findOrCreateFolder(
      account: account,
      headers: headers,
      prefs: prefs,
      parentId: 'root',
      folderName: _folderName,
      folderPath: const ['Parrokit'],
    );
    await prefs.setString(cacheKey, folderId);
    return folderId;
  }

  Future<String> _ensureChildFolder({
    required GoogleSignInAccount account,
    required Map<String, String> headers,
    required SharedPreferences prefs,
    required String parentId,
    required String folderName,
    required List<String> folderPath,
  }) async {
    final cacheKey =
        '${_folderCacheKeyPrefix}_${_accountKey(account)}_${folderPath.join('__')}';
    final cachedFolderId = prefs.getString(cacheKey);
    if (cachedFolderId != null && cachedFolderId.isNotEmpty) {
      final metadata = await fetchFileMetadata(cachedFolderId);
      if (metadata != null &&
          metadata['mimeType'] == 'application/vnd.google-apps.folder' &&
          metadata['trashed'] != true) {
        return cachedFolderId;
      }
    }

    final folderId = await _findOrCreateFolder(
      account: account,
      headers: headers,
      prefs: prefs,
      parentId: parentId,
      folderName: folderName,
      folderPath: folderPath,
    );
    await prefs.setString(cacheKey, folderId);
    return folderId;
  }

  Future<String> _findOrCreateFolder({
    required GoogleSignInAccount account,
    required Map<String, String> headers,
    required SharedPreferences prefs,
    required String parentId,
    required String folderName,
    required List<String> folderPath,
  }) async {
    final existing = await _findFolderByName(
      parentId: parentId,
      folderName: folderName,
      headers: headers,
    );
    if (existing != null) {
      return existing;
    }

    final client = http.Client();
    try {
      final createUri = Uri.https(
        'www.googleapis.com',
        '/drive/v3/files',
        const {'fields': 'id,name'},
      );
      final request = http.Request('POST', createUri);
      request.headers.addAll(headers);
      request.headers['Content-Type'] = 'application/json; charset=UTF-8';
      request.body = jsonEncode({
        'name': folderName,
        'mimeType': 'application/vnd.google-apps.folder',
        'parents': [parentId],
      });

      final response = await client.send(request);
      final body = await response.stream.bytesToString();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          'Google Drive 폴더 생성 실패: ${response.statusCode} $body',
        );
      }

      final data = _asMap(body);
      final folderId = data['id'] as String? ?? '';
      if (folderId.isEmpty) {
        throw StateError('Google Drive 폴더 ID를 받지 못했습니다.');
      }

      await prefs.setString(
        '${_folderCacheKeyPrefix}_${_accountKey(account)}_${folderPath.join('__')}',
        folderId,
      );
      AppLogger.i(
        '[GoogleDrive][Folder] ready account=${_maskAccount(account)} path=${folderPath.join('/')} folderId=$folderId',
      );
      return folderId;
    } finally {
      client.close();
    }
  }

  Future<String?> _findFolderByName({
    required String parentId,
    required String folderName,
    required Map<String, String> headers,
  }) async {
    final client = http.Client();
    try {
      final query = [
        "mimeType = 'application/vnd.google-apps.folder'",
        "trashed = false",
        "name = '${_escapeDriveQuery(folderName)}'",
        "'$parentId' in parents",
      ].join(' and ');
      final uri = Uri.https(
        'www.googleapis.com',
        '/drive/v3/files',
        const {'fields': 'files(id,name,parents)'},
      ).replace(queryParameters: {
        'q': query,
        'fields': 'files(id,name,parents)',
        'pageSize': '1',
      });
      final response = await client.get(uri, headers: headers);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final data = _asMap(response.body);
      final files = data['files'];
      if (files is! List || files.isEmpty) return null;
      final first = files.first;
      if (first is! Map<String, dynamic>) return null;
      return first['id'] as String?;
    } finally {
      client.close();
    }
  }

  Future<String?> _findFileByName({
    required String parentId,
    required String fileName,
    required Map<String, String> headers,
  }) async {
    final client = http.Client();
    try {
      final query = [
        "trashed = false",
        "name = '${_escapeDriveQuery(fileName)}'",
        "'$parentId' in parents",
      ].join(' and ');
      final uri = Uri.https(
        'www.googleapis.com',
        '/drive/v3/files',
      ).replace(queryParameters: {
        'q': query,
        'fields': 'files(id,name,parents)',
        'pageSize': '1',
      });
      final response = await client.get(uri, headers: headers);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final data = _asMap(response.body);
      final files = data['files'];
      if (files is! List || files.isEmpty) return null;
      final first = files.first;
      if (first is! Map<String, dynamic>) return null;
      return first['id'] as String?;
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> _uploadMultipartBytes({
    required String method,
    required String? fileId,
    required Map<String, dynamic> metadata,
    required List<int> bodyBytes,
    required String mimeType,
    required Map<String, String> headers,
  }) async {
    final path = method == 'PATCH' && fileId != null
        ? '/upload/drive/v3/files/$fileId'
        : '/upload/drive/v3/files';
    final uploadUri = Uri.https(
      'www.googleapis.com',
      path,
      const {
        'uploadType': 'multipart',
        'fields': 'id,name,parents',
      },
    );
    final boundary =
        'parrokit-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';
    final client = HttpClient();
    try {
      final request = method == 'PATCH'
          ? await client.patchUrl(uploadUri)
          : await client.postUrl(uploadUri);
      headers.forEach((key, value) {
        request.headers.set(key, value);
      });
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'multipart/related; boundary="$boundary"',
      );
      request.add(_utf8Bytes('--$boundary\r\n'));
      request.add(
        _utf8Bytes('Content-Type: application/json; charset=UTF-8\r\n\r\n'),
      );
      request.add(_utf8Bytes('${jsonEncode(metadata)}\r\n'));
      request.add(_utf8Bytes('--$boundary\r\n'));
      request.add(_utf8Bytes('Content-Type: $mimeType\r\n\r\n'));
      request.add(bodyBytes);
      request.add(_utf8Bytes('\r\n--$boundary--'));

      final response = await request.close();
      final responseBody = await utf8.decodeStream(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          'Google Drive JSON 업로드 실패: ${response.statusCode} $responseBody',
        );
      }
      return _asMap(responseBody);
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, String>> _authorizationHeaders(
    GoogleSignInAccount account,
  ) async {
    final auth = await account.authentication;
    final accessToken = auth.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw StateError('Google Drive access token을 받을 수 없습니다.');
    }

    return {
      'Authorization': 'Bearer $accessToken',
    };
  }

  Map<String, dynamic> _asMap(String responseBody) {
    final decoded = jsonDecode(responseBody);
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{};
  }

  Uint8List _utf8Bytes(String value) => Uint8List.fromList(utf8.encode(value));

  String _accountKey(GoogleSignInAccount account) {
    if (account.email.isNotEmpty) return account.email;
    return 'unknown';
  }

  String _escapeDriveQuery(String value) {
    return value.replaceAll('\\', r'\\').replaceAll("'", r"\'");
  }

  String _fileNameForStoragePath(String storagePath) {
    final segments =
        storagePath.split('/').where((segment) => segment.isNotEmpty).toList();
    if (segments.isEmpty) {
      throw StateError('Google Drive 파일 경로가 올바르지 않습니다.');
    }
    return segments.last;
  }

  String _maskAccount(GoogleSignInAccount account) {
    final email = account.email;
    if (email.isEmpty) return 'unknown';
    final atIndex = email.indexOf('@');
    if (atIndex <= 1) return email;
    return '${email.substring(0, 2)}***${email.substring(atIndex)}';
  }

  String _maskFileName(String fileName) {
    if (fileName.length <= 12) return fileName;
    return '${fileName.substring(0, 8)}...${fileName.substring(fileName.length - 4)}';
  }
}
