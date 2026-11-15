// 클립이 어디에 있는지 적는 말. 위치가 아니라 상태로 적는다(5차).

import 'package:flutter_test/flutter_test.dart';
import 'package:parrokit/core/domain/collection_clip/data/constants/clip_storage_constants.dart';
import 'package:parrokit/features/collection/library/presentation/widgets/storage_state_label.dart';

void main() {
  test('기기 클립은 백업되지 않았다고 말한다', () {
    expect(storageStateLabel(ClipStorageConstants.storageModeLocal), '이 기기에만');
  });

  test('서버 클립은 백업됐다고 말한다', () {
    expect(storageStateLabel(ClipStorageConstants.storageModeServer), '백업됨');
  });

  test('예전 Drive 클립은 따로 적는다', () {
    expect(storageStateLabel(ClipStorageConstants.storageModeGoogleDrive),
        'Drive에 있음');
  });

  test('모르는 값에는 아무 말도 붙이지 않는다', () {
    expect(storageStateLabel('something-else'), isNull);
    expect(storageStateLabel(''), isNull);
  });
}
