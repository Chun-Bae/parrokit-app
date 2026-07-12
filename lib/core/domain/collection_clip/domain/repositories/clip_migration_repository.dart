// ============================================================================
// lib/core/collection_media/domain/repositories/clip_migration_repository.dart
// ============================================================================
//
// [역할]
// Clip의 local ↔ server ↔ gdrive 저장소 이동, 원격 캐시 정리, 저장
// 용량·Google Drive 계정/쿼터 조회를 위한 추상 계약(Repository 인터페이스).
//
// [레이어]
// Core > Collection Media > Domain > Repositories
// ============================================================================

import 'package:parrokit/core/infrastructure/services/cloud/google_drive_storage_service.dart'
    show GoogleDriveStorageQuota;

typedef ClipMigrationProgressCallback = void Function(
  int current,
  int total,
  String message,
);

abstract class ClipMigrationRepository {
  /// 클립 파일을 서버 저장소로 업로드하고 서버 저장 상태로 전환합니다.
  Future<void> moveClipToServer(
    int clipId, {
    ClipMigrationProgressCallback? onProgress,
  });

  /// 클립 파일을 Google Drive로 업로드하고 gdrive 상태로 전환합니다.
  Future<void> moveClipToGoogleDrive(
    int clipId, {
    ClipMigrationProgressCallback? onProgress,
  });

  /// 원격 저장된 클립을 로컬 저장으로 전환합니다.
  Future<void> moveClipToLocal(
    int clipId, {
    ClipMigrationProgressCallback? onProgress,
  });

  Future<bool> clearRemoteClipCache(int clipId);

  /// 현재 로그인된 계정(app_account) 소유의 원격 클립 로컬 캐시를 전부 정리합니다.
  /// 로그아웃 시 호출합니다.
  Future<void> clearCachedFilesForCurrentAccount();

  /// 다른 기기에서 서버로 옮긴 클립 중 이 기기에 없는 것을 받아옵니다.
  /// 새로 반영된 클립 개수를 반환합니다.
  Future<int> pullServerClipsForCurrentAccount();

  /// 다른 기기에서 Google Drive로 옮긴 클립 중 이 기기에 없는 것을
  /// 받아옵니다. 새로 반영된 클립 개수를 반환합니다.
  Future<int> pullCloudClipsForCurrentAccount();

  /// 다른 기기가 서버에 독립적으로 만든 그룹/콜렉션(클립이 없어도) 중 이
  /// 기기에 없는 것을 받아옵니다. 새로 생긴 개수를 반환합니다.
  Future<int> pullServerLibraryStructureForCurrentAccount();

  /// 다른 기기가 클라우드에 독립적으로 만든 그룹/콜렉션 중 이 기기에 없는
  /// 것을 받아옵니다. 새로 생긴 개수를 반환합니다.
  Future<int> pullCloudLibraryStructureForCurrentAccount();

  /// 서버가 source of truth — 원격에서 지워진(더 이상 클립도 없는) 그룹/
  /// 콜렉션을 로컬에서도 정리합니다. 클립 pull이 끝난 뒤에 호출해야
  /// 합니다. 정리된 개수를 반환합니다.
  Future<int> reconcileServerLibraryStructureForCurrentAccount();

  /// 클라우드가 source of truth — 원격에서 지워진 그룹/콜렉션을 로컬에서도
  /// 정리합니다. 클립 pull이 끝난 뒤에 호출해야 합니다.
  Future<int> reconcileCloudLibraryStructureForCurrentAccount();

  Future<int> getServerStorageUsedBytes();

  Future<int> getLocalStorageUsedBytes();

  Future<int> getCloudStorageUsedBytes();

  Future<int> getCachedRemoteStorageUsedBytes();

  Future<int> getCachedRemoteClipCount();

  Future<bool> hasGoogleDriveLinked();

  Future<void> connectGoogleDrive();

  /// 연결된 모든 Google Drive 클립을 로컬로 옮긴 뒤 연결을 해제합니다.
  Future<void> disconnectGoogleDriveAfterLocalMove({
    void Function(int current, int total, String message)? onProgress,
  });

  Future<GoogleDriveStorageQuota?> getGoogleDriveStorageQuota();
}
