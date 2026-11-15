// 클립이 어디에 있는지 적는 말.
//
// 전에는 저장 '위치' 이름('기기'·'서버'·'Google Drive')을 그대로 썼다. 앞으로
// 저장 위치는 사용자가 고르는 것이 아니라 구독이 정하므로, 위치가 아니라
// **상태**로 적는다: 백업이 됐는지, 이 기기에만 있는지(5차).
//
// Google Drive는 더 쓰지 않지만 예전에 올린 클립이 남아 있을 수 있어 그때까지
// 따로 적는다.

import 'package:parrokit/core/domain/collection_clip/data/constants/clip_storage_constants.dart';

String? storageStateLabel(String storageMode) {
  if (storageMode == ClipStorageConstants.storageModeLocal) {
    return '이 기기에만';
  }
  if (storageMode == ClipStorageConstants.storageModeServer) {
    return '백업됨';
  }
  if (storageMode == ClipStorageConstants.storageModeGoogleDrive) {
    return 'Drive에 있음';
  }
  return null;
}
