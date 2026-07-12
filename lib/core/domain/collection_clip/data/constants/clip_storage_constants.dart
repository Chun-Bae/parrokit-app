// ============================================================================
// lib/core/collection_media/data/constants/clip_storage_constants.dart
// ============================================================================
//
// [역할]
// Clip 저장소 동기화 전반에서 공유하는 문자열 상수.
// 이 값들을 각 datasource/repository에서 따로 하드코딩하면 오탈자로 인한
// 가시성/동기화 버그가 재발하기 쉬우므로 반드시 이 상수를 통해서만 사용합니다.
//
// [레이어]
// Core > Collection Media > Data > Constants
// ============================================================================

class ClipStorageConstants {
  ClipStorageConstants._();

  static const String ownerScopeDevice = 'device';
  static const String ownerScopeAppAccount = 'app_account';
  static const String ownerScopeCloudAccount = 'cloud_account';

  static const String providerServer = 'server';
  static const String providerGoogleDrive = 'gdrive';

  static const String storageModeLocal = 'local';
  static const String storageModeServer = 'server';
  static const String storageModeGoogleDrive = 'gdrive';

  /// 서버 스토리지 유료화 준비 중 — 결제 연동 전까지 UI에서 잠가둔다.
  /// 결제가 붙으면 이 값을 false로 바꾼다.
  static const bool isServerStorageLocked = true;
}
