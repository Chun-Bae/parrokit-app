// 글 사진 지우기는 한꺼번에 보낸다(5차 511).
//
// R2로 옮긴 뒤로 지우기가 Cloud Function 호출이다. 한 장씩 await 하면
// 사진 세 장짜리 글은 왕복이 세 번이고, 함수가 자고 있으면 첫 호출에만
// 20초가 걸린다. 그동안 글이 화면에서 사라지지 않는다.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/infrastructure/services/cloud/user_file_storage.dart';
import 'package:parrokit/features/community/shell/data/services/community_image_service.dart';

class _SlowStorage implements UserFileStorage {
  int running = 0;
  int peak = 0;
  final List<String> deleted = [];

  @override
  Future<bool> deleteQuietly({String? path, String? url}) async {
    running++;
    if (running > peak) peak = running;
    await Future<void>.delayed(const Duration(milliseconds: 30));
    running--;
    deleted.add(url ?? path ?? '');
    return true;
  }

  @override
  Future<void> downloadToFile({
    String? path,
    String? url,
    required File destination,
    void Function(int received, int total)? onProgress,
  }) async =>
      throw UnimplementedError();

  @override
  Future<UploadedFile> uploadBytes(
    Uint8List bytes, {
    required String path,
    String? contentType,
    void Function(int sent, int total)? onProgress,
  }) async =>
      throw UnimplementedError();

  @override
  Future<UploadedFile> uploadFile(
    File file, {
    required String path,
    String? contentType,
    void Function(int sent, int total)? onProgress,
  }) async =>
      throw UnimplementedError();
}

void main() {
  late _SlowStorage fake;

  // 원래 구현(R2StorageService)은 Firebase가 있어야 만들어진다. 테스트에서는
  // 읽기만 해도 터지므로 되돌리지 않고 가짜만 꽂는다. 파일마다 아이솔레이트가
  // 따로라 다른 테스트에 새지 않는다.
  setUp(() {
    fake = _SlowStorage();
    UserFileStorage.instance = fake;
  });

  test('사진 세 장을 한꺼번에 지운다', () async {
    await CommunityImageService().deleteImagesQuietly([
      'https://example.com/a.jpg',
      'https://example.com/b.jpg',
      'https://example.com/c.jpg',
    ]);

    expect(fake.deleted.length, 3);
    // 하나씩 기다렸으면 peak가 1이다.
    expect(fake.peak, 3);
  });

  test('지울 사진이 없으면 아무것도 부르지 않는다', () async {
    await CommunityImageService().deleteImagesQuietly(const []);
    expect(fake.deleted, isEmpty);
  });
}
