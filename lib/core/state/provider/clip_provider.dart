// ============================================================================
// lib/core/state/provider/clip_provider.dart
// ============================================================================
//
// [역할]
// 클립 데이터 조회 및 선택 상태 관리 (Collection -> Clip)
//
// [레이어]
// Core > State > Provider
// ============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../../data/local/app_database.dart';
import 'package:drift/drift.dart';
import '../../../data/models/clip_view.dart';
import '../../../../data/models/clip_item.dart';

import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:parrokit/core/infrastructure/services/cloud/google_drive_storage_service.dart';
import 'package:parrokit/core/domain/collection_clip/data/constants/clip_storage_constants.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/remote_doc_id_resolver.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/clip_source_ref_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/clip_thumbnail_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/clip_file_sync_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/collection_group_mirror_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/clip_remote_library_sync_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/clip_item_query_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/clip_detail_query_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/clip_firestore_metadata_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/clip_cloud_metadata_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/library_entity_remote_sync_datasource.dart';
import 'package:parrokit/core/domain/collection_clip/data/datasources/library_entity_sync_coordinator.dart';
import 'package:parrokit/core/domain/collection_clip/data/repositories/clip_repository_impl.dart';
import 'package:parrokit/core/domain/collection_clip/data/repositories/clip_migration_repository_impl.dart';
import 'package:parrokit/core/domain/collection_clip/data/repositories/group_repository_impl.dart';
import 'package:parrokit/core/domain/collection_clip/data/repositories/collection_repository_impl.dart';
import 'package:parrokit/core/domain/collection_clip/domain/repositories/clip_repository.dart';
import 'package:parrokit/core/domain/collection_clip/domain/repositories/clip_migration_repository.dart';
import 'package:parrokit/core/domain/collection_clip/domain/repositories/group_repository.dart';
import 'package:parrokit/core/domain/collection_clip/domain/repositories/collection_repository.dart';
import 'mixins/clip_tag_mixin.dart';
import 'mixins/clip_action_mixin.dart';

class ClipProvider extends ChangeNotifier with ClipTagMixin, ClipActionMixin {
  static const int serverStorageQuotaBytes = 1024 * 1024 * 1024;

  @override
  final AppDatabase db;
  late final ClipRepository _clipRepository;
  late final ClipMigrationRepository _clipMigrationRepository;
  late final GroupRepository _groupRepository;
  late final CollectionRepository _collectionRepository;
  late final LibraryEntitySyncCoordinator _libraryEntitySyncCoordinator;

  @override
  LibraryEntitySyncCoordinator get libraryEntitySyncCoordinator =>
      _libraryEntitySyncCoordinator;

  @override
  ClipRepository get service => _clipRepository;

  @override
  ClipMigrationRepository get migrationService => _clipMigrationRepository;

  ClipProvider(this.db) {
    // datasource들은 계정 상태(GoogleSignIn 등)를 공유해야 하므로 단일
    // 인스턴스를 만들어 두 Repository(Clip/ClipMigration)에 함께 주입합니다.
    final googleDriveStorageService = GoogleDriveStorageService();
    final sourceRefDatasource =
        ClipSourceRefDatasource(db, googleDriveStorageService);
    final thumbnailDatasource = ClipThumbnailDatasource(
      db,
      sourceRefDatasource,
      googleDriveStorageService,
    );
    final fileSyncDatasource = ClipFileSyncDatasource(
      db,
      sourceRefDatasource,
      googleDriveStorageService,
    );
    final itemQueryDatasource = ClipItemQueryDatasource(
      db,
      sourceRefDatasource,
      thumbnailDatasource,
    );
    final remoteDocIdResolver = RemoteDocIdResolver();
    final detailQueryDatasource = ClipDetailQueryDatasource(db);
    final firestoreMetadataDatasource = ClipFirestoreMetadataDatasource(db);
    final remoteLibrarySyncDatasource = ClipRemoteLibrarySyncDatasource(
      db,
      firestoreMetadataDatasource,
      sourceRefDatasource,
      googleDriveStorageService,
    );
    final cloudMetadataDatasource = ClipCloudMetadataDatasource(
      db,
      detailQueryDatasource,
    );
    final libraryEntityRemoteSyncDatasource = LibraryEntityRemoteSyncDatasource(
      firestoreMetadataDatasource,
      googleDriveStorageService,
    );
    _libraryEntitySyncCoordinator = LibraryEntitySyncCoordinator(
      db,
      libraryEntityRemoteSyncDatasource,
      remoteDocIdResolver,
    );
    final collectionGroupMirrorDatasource = CollectionGroupMirrorDatasource(
      db,
      _libraryEntitySyncCoordinator,
    );

    _clipRepository = ClipRepositoryImpl(
      db: db,
      sourceRefDatasource: sourceRefDatasource,
      thumbnailDatasource: thumbnailDatasource,
      fileSyncDatasource: fileSyncDatasource,
      itemQueryDatasource: itemQueryDatasource,
      firestoreMetadataDatasource: firestoreMetadataDatasource,
      libraryEntitySyncCoordinator: _libraryEntitySyncCoordinator,
    );
    _clipMigrationRepository = ClipMigrationRepositoryImpl(
      db: db,
      sourceRefDatasource: sourceRefDatasource,
      thumbnailDatasource: thumbnailDatasource,
      fileSyncDatasource: fileSyncDatasource,
      collectionGroupMirrorDatasource: collectionGroupMirrorDatasource,
      remoteLibrarySyncDatasource: remoteLibrarySyncDatasource,
      firestoreMetadataDatasource: firestoreMetadataDatasource,
      cloudMetadataDatasource: cloudMetadataDatasource,
      detailQueryDatasource: detailQueryDatasource,
      remoteDocIdResolver: remoteDocIdResolver,
      googleDriveStorageService: googleDriveStorageService,
      libraryEntitySyncCoordinator: _libraryEntitySyncCoordinator,
    );
    _groupRepository = GroupRepositoryImpl(db);
    _collectionRepository = CollectionRepositoryImpl(db);
  }

  // ─────────────────────────────────────────────────────────────────
  // State
  // ─────────────────────────────────────────────────────────────────

  /// 현재 활성화된 저장위치 탭 (로컬/서버/클라우드). 그룹/컬렉션 목록 조회는
  /// 전부 이 값을 기준으로 스코프됩니다.
  String _activeStorageMode = ClipStorageConstants.storageModeLocal;
  String get activeStorageMode => _activeStorageMode;

  List<Group> groups = [];
  @override
  int? selectedGroupId;

  List<Collection> collections = [];
  @override
  int? selectedCollectionId;

  List<ClipItem> clipItems = [];
  List<Clip> clips = [];
  Map<int, List<Tag>> tagsByClip = {};
  int serverStorageUsedBytes = 0;
  int localStorageUsedBytes = 0;
  int googleDriveUsedBytes = 0;
  int cloudStorageUsedBytes = 0;
  int cachedRemoteStorageUsedBytes = 0;
  int cachedRemoteClipCount = 0;
  int? cloudStorageQuotaBytes;
  bool hasGoogleDriveLinked = false;
  bool _isCollectionMenuOpen = false;
  final Set<int> _selectedClipIds = <int>{};
  bool _isGoogleDriveLinking = false;
  String _googleDriveLinkMessage = '';
  String? _googleDriveLinkError;

  // 저장위치 이동 진행 상태 (단일 클립 이동 + 다중 선택 이동 공용). 진행
  // 중에는 전체 화면 오버레이로 다른 조작을 막고, 실패 시 사용자가 직접
  // 닫을 때까지 오류 메시지를 보여준다.
  bool _isStorageTransferRunning = false;
  bool _storageTransferSucceeded = false;
  int _storageTransferProgress = 0;
  int _storageTransferTotal = 0;
  String _storageTransferTitle = '';
  String _storageTransferMessage = '';
  String? _storageTransferError;

  // ─────────────────────────────────────────────────────────────────
  // Methods
  // ─────────────────────────────────────────────────────────────────

  Future<ClipView?> fetchClipById(int clipId) async {
    return _clipRepository.fetchClipById(clipId);
  }

  Future<List<ClipItem>> fetchClipItemsByStorageMode(
    String storageMode,
  ) async {
    return _clipRepository.fetchClipItemsByStorageMode(storageMode);
  }

  Future<List<ClipItem>> fetchCachedRemoteClipItems() {
    return _clipRepository.fetchCachedRemoteClipItems();
  }

  Future<void> refreshServerStorageUsage() async {
    await refreshStorageUsage();
  }

  @override
  Future<void> refreshStorageUsage() async {
    serverStorageUsedBytes =
        await _clipMigrationRepository.getServerStorageUsedBytes();
    localStorageUsedBytes =
        await _clipMigrationRepository.getLocalStorageUsedBytes();
    cloudStorageUsedBytes =
        await _clipMigrationRepository.getCloudStorageUsedBytes();
    cachedRemoteStorageUsedBytes =
        await _clipMigrationRepository.getCachedRemoteStorageUsedBytes();
    cachedRemoteClipCount =
        await _clipMigrationRepository.getCachedRemoteClipCount();
    hasGoogleDriveLinked =
        await _clipMigrationRepository.hasGoogleDriveLinked();

    try {
      final quota = await _clipMigrationRepository.getGoogleDriveStorageQuota();
      googleDriveUsedBytes = quota?.usedBytes ?? 0;
      cloudStorageQuotaBytes = quota?.limitBytes;
    } catch (_) {
      googleDriveUsedBytes = 0;
      cloudStorageQuotaBytes = null;
    }

    // 일부 호출부(캐시 관리 화면, 로그아웃 등)가 이 메서드만 부르고 별도로
    // notifyListeners를 호출하지 않아, 값은 갱신됐는데 다른 화면(더보기의
    // 저장 공간 섹션 등)이 즉시 반영되지 않는 문제가 있었다. 이 메서드
    // 자체에서 항상 알려주도록 통일한다.
    notifyListeners();
  }

  /// [refreshStorageUsage]는 Google Drive 연동 여부/용량 조회 등 네트워크
  /// 호출을 포함해 느릴 수 있습니다. 그룹/컬렉션 선택처럼 즉시 반응해야
  /// 하는 화면 전환에서 이 값을 기다리면 탭할 때마다 버벅이므로, 화면
  /// 전환은 먼저 반영하고 저장공간 숫자는 백그라운드에서 뒤늦게 갱신합니다.
  void _refreshStorageUsageInBackground() {
    unawaited(
      refreshStorageUsage().then((_) => notifyListeners()).catchError((e, st) {
        AppLogger.w('[Clip][Storage] background-refresh failed', error: e);
      }),
    );
  }

  bool get isGoogleDriveLinking => _isGoogleDriveLinking;
  String get googleDriveLinkMessage => _googleDriveLinkMessage;
  String? get googleDriveLinkError => _googleDriveLinkError;
  bool get shouldShowGoogleDriveLinkBanner =>
      _isGoogleDriveLinking || _googleDriveLinkError != null;
  bool get isCollectionMenuOpen => _isCollectionMenuOpen;
  bool get hasSelectedClips => _selectedClipIds.isNotEmpty;
  Set<int> get selectedClipIds => Set.unmodifiable(_selectedClipIds);
  bool isClipSelected(int clipId) => _selectedClipIds.contains(clipId);
  bool get isStorageTransferRunning => _isStorageTransferRunning;
  bool get storageTransferSucceeded => _storageTransferSucceeded;
  int get storageTransferProgress => _storageTransferProgress;
  int get storageTransferTotal => _storageTransferTotal;
  String get storageTransferTitle => _storageTransferTitle;
  String get storageTransferMessage => _storageTransferMessage;
  String? get storageTransferError => _storageTransferError;

  /// 진행 중이거나(성공 직후 짧게 보여주는 동안 포함) 오류가 남아있으면
  /// (사용자가 닫기 전까지) 전체 화면 오버레이를 계속 보여줍니다.
  bool get shouldShowStorageTransferOverlay =>
      _isStorageTransferRunning ||
      _storageTransferSucceeded ||
      _storageTransferError != null;

  /// 오버레이의 오류 상태를 사용자가 직접 닫을 때 호출합니다.
  void dismissStorageTransferError() {
    if (_storageTransferError == null) return;
    _storageTransferError = null;
    notifyListeners();
  }

  void selectAllVisibleClips() {
    for (final item in clipItems) {
      _selectedClipIds.add(item.clip.id);
    }
    notifyListeners();
  }

  @override
  Future<bool> moveClipToServer(int clipId) => _runSingleClipTransfer(
        clipId: clipId,
        title: '서버로 옮기는 중',
        action: (onProgress) => _clipMigrationRepository.moveClipToServer(
          clipId,
          onProgress: onProgress,
        ),
        successMessage: '서버 저장을 마쳤어요',
        failureMessage: '서버 저장에 실패했어요. 잠시 후 다시 시도해 주세요.',
        logTag: 'move-to-server',
      );

  @override
  Future<bool> moveClipToGoogleDrive(int clipId) => _runSingleClipTransfer(
        clipId: clipId,
        title: 'Google Drive로 옮기는 중',
        action: (onProgress) => _clipMigrationRepository.moveClipToGoogleDrive(
          clipId,
          onProgress: onProgress,
        ),
        successMessage: 'Google Drive 저장을 마쳤어요',
        failureMessage: 'Google Drive 저장에 실패했어요. 잠시 후 다시 시도해 주세요.',
        logTag: 'move-to-gdrive',
      );

  @override
  Future<bool> moveClipToLocal(int clipId) => _runSingleClipTransfer(
        clipId: clipId,
        title: '내 기기로 옮기는 중',
        action: (onProgress) => _clipMigrationRepository.moveClipToLocal(
          clipId,
          onProgress: onProgress,
        ),
        successMessage: '내 기기로 옮겼어요',
        failureMessage: '내 기기로 옮기지 못했어요. 잠시 후 다시 시도해 주세요.',
        logTag: 'move-to-local',
      );

  /// 클립 1개를 로컬/서버/Google Drive 사이로 옮기는 공용 처리. 진행 중에는
  /// 전체 화면 오버레이(`shouldShowStorageTransferOverlay`)로 다른 조작을
  /// 막고, 실패하면 사용자가 직접 닫을 때까지 오류를 보여준다.
  Future<bool> _runSingleClipTransfer({
    required int clipId,
    required String title,
    required Future<void> Function(ClipMigrationProgressCallback onProgress)
        action,
    required String successMessage,
    required String failureMessage,
    required String logTag,
  }) async {
    if (_isStorageTransferRunning) return false;

    startStorageTransfer(0, '준비하고 있어요', title: title);

    try {
      await action((current, total, message) {
        if (total > 0) _storageTransferTotal = total;
        updateStorageTransfer(current, message);
      });
      endStorageTransfer(message: successMessage);
      await _refreshCollectionsInBackground();
      return true;
    } catch (e, st) {
      AppLogger.e(
        '[Clip][Storage] $logTag failed clipId=$clipId',
        error: e,
        stackTrace: st,
      );
      _isStorageTransferRunning = false;
      _storageTransferSucceeded = false;
      _storageTransferError = failureMessage;
      notifyListeners();
      return false;
    }
  }

  /// 클립 이동으로 이전 콜렉션이 비어 자동 삭제됐을 수 있어, 현재 그룹의
  /// 콜렉션 목록을 조용히 다시 불러온다. selectedCollectionId 등 클립 목록
  /// 상태는 건드리지 않아, 클립 목록을 보고 있던 화면이 그룹 목록으로
  /// 튕기지 않는다.
  Future<void> _refreshCollectionsInBackground() async {
    if (selectedGroupId == null) return;
    try {
      collections = await _collectionRepository.getVisibleCollectionsForGroup(
        selectedGroupId,
        _activeStorageMode,
      );
      notifyListeners();
    } catch (e) {
      AppLogger.w('[Clip][Storage] collections-refresh failed', error: e);
    }
  }

  /// 클립 1개 삭제. 원격(server/gdrive) 클립은 원격 파일 삭제 네트워크
  /// 호출이 걸려 시간이 걸릴 수 있어, 이동과 같은 오버레이로 진행 중임을
  /// 보여준다.
  @override
  Future<bool> deleteClipById(int clipId) async {
    if (_isStorageTransferRunning) return false;

    startStorageTransfer(0, '클립을 지우고 있어요', title: '삭제하는 중');

    try {
      final success = await super.deleteClipById(clipId);
      if (!success) {
        _isStorageTransferRunning = false;
        _storageTransferSucceeded = false;
        _storageTransferError = '삭제하지 못했어요. 잠시 후 다시 시도해 주세요.';
        notifyListeners();
        return false;
      }
      endStorageTransfer(message: '삭제했어요');
      return true;
    } catch (e, st) {
      AppLogger.e(
        '[Clip][Storage] delete-clip failed clipId=$clipId',
        error: e,
        stackTrace: st,
      );
      _isStorageTransferRunning = false;
      _storageTransferSucceeded = false;
      _storageTransferError = '삭제하지 못했어요. 잠시 후 다시 시도해 주세요.';
      notifyListeners();
      return false;
    }
  }

  /// 콜렉션 삭제(안의 클립도 함께 삭제). 콜렉션 안 클립이 원격에 있으면
  /// 삭제에 네트워크 호출이 걸리므로 오버레이로 진행 중임을 보여준다.
  @override
  Future<bool> deleteCollectionById(int collectionId) async {
    if (_isStorageTransferRunning) return false;

    startStorageTransfer(0, '콜렉션을 지우고 있어요', title: '삭제하는 중');

    try {
      final success = await super.deleteCollectionById(collectionId);
      endStorageTransfer(message: '콜렉션을 지웠어요');
      return success;
    } catch (e, st) {
      AppLogger.e(
        '[Clip][Storage] delete-collection failed collectionId=$collectionId',
        error: e,
        stackTrace: st,
      );
      _isStorageTransferRunning = false;
      _storageTransferSucceeded = false;
      _storageTransferError = '콜렉션을 지우지 못했어요. 잠시 후 다시 시도해 주세요.';
      notifyListeners();
      return false;
    }
  }

  /// 선택한 여러 클립을 한 번에 삭제합니다. 개별 [deleteClipById]가 각자
  /// 오버레이를 열고 닫으면 여러 개일 때 화면이 깜빡이므로, 여기서는
  /// 저장소를 직접 호출해 하나의 오버레이 안에서 진행 개수를 보여줍니다.
  Future<void> deleteClipsById(List<int> clipIds) async {
    if (clipIds.isEmpty || _isStorageTransferRunning) return;

    final total = clipIds.length;
    startStorageTransfer(total, '$total개 클립을 지우고 있어요', title: '삭제하는 중');

    try {
      var progress = 0;
      for (final clipId in clipIds) {
        await _clipRepository.deleteClipById(clipId);
        progress++;
        updateStorageTransfer(progress, '$progress/$total개 지웠어요');
      }

      if (selectedCollectionId != null) {
        await selectCollection(selectedCollectionId);
      } else {
        await refreshStorageUsage();
      }
      endStorageTransfer(message: '$total개 클립을 모두 지웠어요');
      await _refreshCollectionsInBackground();
    } catch (e, st) {
      AppLogger.e(
        '[Clip][Storage] bulk-delete failed',
        error: e,
        stackTrace: st,
      );
      _isStorageTransferRunning = false;
      _storageTransferSucceeded = false;
      _storageTransferError = '지우는 중 문제가 생겼어요. 잠시 후 다시 시도해 주세요.';
      notifyListeners();
    }
  }

  Future<bool> connectGoogleDrive() async {
    if (_isGoogleDriveLinking) return false;

    _setGoogleDriveLinkState(
      isRunning: true,
      message: 'Google Drive를 연결하는 중',
      error: null,
    );

    try {
      await _clipMigrationRepository.connectGoogleDrive();
      await refreshStorageUsage();
      _setGoogleDriveLinkState(
        isRunning: false,
        message: 'Google Drive 연결 완료',
        error: null,
      );
      return true;
    } catch (e, st) {
      AppLogger.e(
        '[Clip][Cloud] connect-google-drive failed',
        error: e,
        stackTrace: st,
      );
      _setGoogleDriveLinkState(
        isRunning: false,
        message: 'Google Drive 연결 실패',
        error: e.toString(),
      );
      return false;
    } finally {
      notifyListeners();
    }
  }

  Future<bool> disconnectGoogleDrive() async {
    if (_isGoogleDriveLinking) return false;

    _setGoogleDriveLinkState(
      isRunning: true,
      message: 'Google Drive 파일을 로컬로 옮기는 중',
      error: null,
    );

    try {
      await _clipMigrationRepository.disconnectGoogleDriveAfterLocalMove(
        onProgress: (current, total, message) {
          _setGoogleDriveLinkState(
            isRunning: true,
            message: total == 0 ? message : '$message ($current/$total)',
            error: null,
          );
        },
      );
      await refreshStorageUsage();
      _setGoogleDriveLinkState(
        isRunning: false,
        message: 'Google Drive 연동 해제 완료',
        error: null,
      );
      return true;
    } catch (e, st) {
      AppLogger.e(
        '[Clip][Cloud] disconnect-google-drive failed',
        error: e,
        stackTrace: st,
      );
      _setGoogleDriveLinkState(
        isRunning: false,
        message: 'Google Drive 연동 해제 실패',
        error: e.toString(),
      );
      return false;
    } finally {
      notifyListeners();
    }
  }

  void toggleCollectionMenu() {
    if (_isCollectionMenuOpen) {
      closeCollectionMenu();
    } else {
      openCollectionMenu();
    }
  }

  void openCollectionMenu() {
    if (_isCollectionMenuOpen) return;
    _isCollectionMenuOpen = true;
    _selectedClipIds.clear();
    notifyListeners();
  }

  void closeCollectionMenu() {
    if (!_isCollectionMenuOpen) return;
    _isCollectionMenuOpen = false;
    _selectedClipIds.clear();
    notifyListeners();
  }

  /// 계정 전환(로그아웃) 시 이전 세션에서 멈춰있을 수 있는 선택/진행 상태를
  /// 강제로 초기화합니다. 특정 작업이 완료 신호 없이 끊기면(네트워크 끊김 등)
  /// 선택 모드나 전체 화면 오버레이가 남아 다음 계정 세션까지 화면이
  /// 반응하지 않는 것처럼 보일 수 있어, 로그아웃 시점에 안전하게 리셋합니다.
  void resetTransientUiState() {
    _isCollectionMenuOpen = false;
    _selectedClipIds.clear();
    _isStorageTransferRunning = false;
    _storageTransferSucceeded = false;
    _storageTransferProgress = 0;
    _storageTransferTotal = 0;
    _storageTransferTitle = '';
    _storageTransferMessage = '';
    _storageTransferError = null;
    _isGoogleDriveLinking = false;
    _googleDriveLinkMessage = '';
    _googleDriveLinkError = null;
    notifyListeners();
  }

  void toggleClipSelection(int clipId) {
    if (_selectedClipIds.contains(clipId)) {
      _selectedClipIds.remove(clipId);
    } else {
      _selectedClipIds.add(clipId);
    }
    notifyListeners();
  }

  void clearClipSelection() {
    if (_selectedClipIds.isEmpty) return;
    _selectedClipIds.clear();
    notifyListeners();
  }

  void startStorageTransfer(
    int total,
    String message, {
    String title = '클립을 옮기는 중',
  }) {
    _isStorageTransferRunning = true;
    _storageTransferSucceeded = false;
    _storageTransferProgress = 0;
    _storageTransferTotal = total;
    _storageTransferTitle = title;
    _storageTransferMessage = message;
    _storageTransferError = null;
    notifyListeners();
  }

  void updateStorageTransfer(int progress, String message) {
    _isStorageTransferRunning = true;
    _storageTransferProgress = progress;
    _storageTransferTotal =
        _storageTransferTotal == 0 ? progress : _storageTransferTotal;
    _storageTransferMessage = message;
    notifyListeners();
  }

  /// 성공적으로 끝난 뒤, 사용자가 결과를 인지할 수 있도록 잠깐 완료 상태를
  /// 보여준 다음 오버레이를 닫습니다.
  void endStorageTransfer({String message = '전환을 마쳤어요'}) {
    _isStorageTransferRunning = false;
    _storageTransferSucceeded = true;
    _storageTransferProgress = _storageTransferTotal;
    _storageTransferMessage = message;
    notifyListeners();
    unawaited(
      Future.delayed(const Duration(milliseconds: 700), () {
        if (_storageTransferSucceeded) {
          _storageTransferSucceeded = false;
          notifyListeners();
        }
      }),
    );
  }

  /// 선택한 여러 클립을 한 번에 다른 저장위치로 옮깁니다. 클립 1개짜리
  /// 이동(moveClipToServer 등)과 같은 오버레이 상태를 공유하므로, 그
  /// 메서드들이 각자 오버레이를 열고 닫지 않도록 여기서는 저장소를 직접
  /// 호출합니다.
  Future<void> moveClipsToStorage(
    List<int> clipIds,
    String target,
  ) async {
    if (clipIds.isEmpty || _isStorageTransferRunning) return;

    final title = switch (target) {
      ClipStorageConstants.storageModeLocal => '내 기기로 옮기는 중',
      ClipStorageConstants.storageModeServer => '서버로 옮기는 중',
      ClipStorageConstants.storageModeGoogleDrive => 'Google Drive로 옮기는 중',
      _ => '클립을 옮기는 중',
    };

    final total = clipIds.length;
    startStorageTransfer(total, '$total개 클립을 옮길 준비를 하고 있어요', title: title);

    try {
      var progress = 0;
      for (final clipId in clipIds) {
        switch (target) {
          case ClipStorageConstants.storageModeLocal:
            await _clipMigrationRepository.moveClipToLocal(clipId);
            break;
          case ClipStorageConstants.storageModeServer:
            await _clipMigrationRepository.moveClipToServer(clipId);
            break;
          case ClipStorageConstants.storageModeGoogleDrive:
            await _clipMigrationRepository.moveClipToGoogleDrive(clipId);
            break;
        }

        progress++;
        updateStorageTransfer(progress, '$progress/$total개 클립을 옮겼어요');
      }

      if (selectedCollectionId != null) {
        await selectCollection(selectedCollectionId);
      } else {
        await refreshStorageUsage();
      }
      endStorageTransfer(message: '$total개 클립을 모두 옮겼어요');
      await _refreshCollectionsInBackground();
    } catch (e, st) {
      AppLogger.e(
        '[Clip][Storage] bulk-transfer failed target=$target',
        error: e,
        stackTrace: st,
      );
      _isStorageTransferRunning = false;
      _storageTransferSucceeded = false;
      _storageTransferError = '옮기는 중 문제가 생겼어요. 잠시 후 다시 시도해 주세요.';
      notifyListeners();
    } finally {
      closeCollectionMenu();
    }
  }

  /// 활성 저장위치 탭을 바꾸고 그 탭의 그룹 목록을 새로 불러옵니다.
  /// 화면 진입 시 초기 로드에도 쓰이므로, 값이 같아 보여도 항상 다시
  /// 불러옵니다 (탭 재탭 방지는 호출부에서 처리).
  Future<void> setActiveStorageMode(String storageMode) async {
    _activeStorageMode = storageMode;
    await loadGroups();
  }

  /// 다른 기기에서 서버로 옮긴 클립을 이 기기로 받아옵니다. 로그인 직후와
  /// 서버 탭의 pull-to-refresh에서 호출합니다. 서버 탭이 활성 상태면 목록도
  /// 새로고침합니다. 서버가 source of truth이므로 순서대로: (1) 빈 그룹/
  /// 콜렉션도 먼저 당겨와서 클립의 collectionRemoteId 매칭이 가능하게 하고,
  /// (2) 클립을 당겨오면서 원격에서 지워진 클립은 로컬에서도 정리하고,
  /// (3) 클립 정리가 끝난 뒤 이제 비어버린 그룹/콜렉션 중 원격에도 없는
  /// 것을 정리합니다 (클립이 남아있는 동안은 FK 때문에 못 지우므로 순서가
  /// 중요합니다).
  Future<int> pullRemoteServerClips() => _pullRemoteClips(
        pull: () async {
          final libraryCount = await _clipMigrationRepository
              .pullServerLibraryStructureForCurrentAccount();
          final clipCount =
              await _clipMigrationRepository.pullServerClipsForCurrentAccount();
          final reconcileCount = await _clipMigrationRepository
              .reconcileServerLibraryStructureForCurrentAccount();
          return libraryCount + clipCount + reconcileCount;
        },
        matchingStorageMode: ClipStorageConstants.storageModeServer,
      );

  /// 다른 기기에서 Google Drive로 옮긴 클립을 이 기기로 받아옵니다. 로그인
  /// 직후와 클라우드 탭의 pull-to-refresh에서 호출합니다. Drive가 source
  /// of truth이므로 클립·그룹·콜렉션 모두 원격에 없으면 로컬에서도
  /// 정리합니다 (순서는 서버 pull과 동일).
  Future<int> pullRemoteCloudClips() => _pullRemoteClips(
        pull: () async {
          final libraryCount = await _clipMigrationRepository
              .pullCloudLibraryStructureForCurrentAccount();
          final clipCount =
              await _clipMigrationRepository.pullCloudClipsForCurrentAccount();
          final reconcileCount = await _clipMigrationRepository
              .reconcileCloudLibraryStructureForCurrentAccount();
          return libraryCount + clipCount + reconcileCount;
        },
        matchingStorageMode: ClipStorageConstants.storageModeGoogleDrive,
      );

  /// 로그인 직후 자동 pull과 사용자의 수동 pull-to-refresh가 겹치면, 서로
  /// 모르는 채로 같은 remoteDocId를 동시에 로컬에 두 번 만들 수 있습니다.
  /// 저장위치별로 한 번에 하나만 돌게 막습니다.
  final Set<String> _activePulls = {};

  Future<int> _pullRemoteClips({
    required Future<int> Function() pull,
    required String matchingStorageMode,
  }) async {
    if (!_activePulls.add(matchingStorageMode)) return 0;
    try {
      final pulledCount = await pull();
      if (pulledCount > 0 && _activeStorageMode == matchingStorageMode) {
        await loadGroups();
      }
      return pulledCount;
    } finally {
      _activePulls.remove(matchingStorageMode);
    }
  }

  /// 모든 그룹 로드 (현재 활성 저장위치 탭 기준).
  @override
  Future<void> loadGroups() async {
    groups = await _groupRepository.getAllGroups(_activeStorageMode);
    closeCollectionMenu();

    // 초기화
    selectedGroupId = null;
    selectedCollectionId = null;
    collections = [];
    clips = [];
    clipItems = [];
    tagsByClip = {};
    notifyListeners();
    _refreshStorageUsageInBackground();
  }

  /// 그룹 선택. 그룹에 속한 컬렉션 목록을 불러옵니다.
  /// id가 null이면 소속 그룹이 없는 최상위 컬렉션을 불러옵니다.
  @override
  Future<void> selectGroup(int? id) async {
    closeCollectionMenu();
    selectedGroupId = id;
    selectedCollectionId = null;
    clips = [];
    clipItems = [];
    tagsByClip = {};

    if (id == null) {
      collections = await _collectionRepository.getVisibleCollectionsForGroup(
          null, _activeStorageMode);
    } else if (id == -1) {
      collections = await _collectionRepository.getVisibleCollectionsForGroup(
          -1, _activeStorageMode);
    } else {
      collections = await _collectionRepository.getVisibleCollectionsForGroup(
          id, _activeStorageMode);
    }

    notifyListeners();
    _refreshStorageUsageInBackground();
  }

  /// 새 그룹 생성 후 목록 갱신. 서버/클라우드 탭이면 원격에도 독립 저장.
  Future<void> createGroup(String name) async {
    await _libraryEntitySyncCoordinator.createGroup(name, _activeStorageMode);
    await loadGroups();
  }

  /// 그룹 이름 변경 후 목록 갱신. 원격에 동기화된 그룹이면 원격도 갱신.
  Future<void> renameGroup(int id, String name) async {
    await _libraryEntitySyncCoordinator.renameGroup(id, name);
    await loadGroups();
  }

  /// 그룹 삭제 후 목록 갱신. 원격에 동기화된 그룹이면 원격도 함께 삭제.
  /// 원격 삭제는 네트워크 호출이 걸리므로 클립/콜렉션 삭제와 같은
  /// 오버레이로 진행 중임을 보여준다.
  Future<void> deleteGroupById(int id) async {
    if (_isStorageTransferRunning) return;

    startStorageTransfer(0, '그룹을 지우고 있어요', title: '삭제하는 중');

    try {
      await _libraryEntitySyncCoordinator.deleteGroup(id);
      await _groupRepository.deleteGroupById(id);
      if (selectedGroupId == id) {
        selectedGroupId = null;
      }
      await loadGroups();
      endStorageTransfer(message: '그룹을 지웠어요');
    } catch (e, st) {
      AppLogger.e(
        '[Clip][Storage] delete-group failed groupId=$id',
        error: e,
        stackTrace: st,
      );
      _isStorageTransferRunning = false;
      _storageTransferSucceeded = false;
      _storageTransferError = '그룹을 지우지 못했어요. 잠시 후 다시 시도해 주세요.';
      notifyListeners();
    }
  }

  /// 모든 컬렉션 로드 (호환성 또는 필요 시 사용).
  @override
  Future<void> loadCollections() async {
    collections = await _collectionRepository
        .getAllVisibleCollections(_activeStorageMode);
    notifyListeners();
    _refreshStorageUsageInBackground();
  }

  /// 컬렉션 선택 (null이면 컬렉션 없는 클립 표시, -1이면 현재 스코프의
  /// "모든 클립" 가상 뷰: 그룹 루트(-1)에서는 저장위치 전체 클립, 실제
  /// 그룹 안에서는 그 그룹에 속한 콜렉션들의 클립을 합쳐서 보여줍니다).
  @override
  Future<void> selectCollection(int? id) async {
    selectedCollectionId = id;
    clips = [];
    clipItems = [];
    tagsByClip = {};

    if (id == null) {
      clips = await _clipRepository.getVisibleClipsForCollection(null);
    } else if (id == -1) {
      clips = (selectedGroupId == null || selectedGroupId == -1)
          ? await _clipRepository
              .getVisibleClipsForStorageMode(_activeStorageMode)
          : await _clipRepository.getVisibleClipsForCollections(
              collections.map((c) => c.id).toList(),
            );
    } else {
      clips = await _clipRepository.getVisibleClipsForCollection(id);
    }

    await _buildClipItems();
    notifyListeners();
    _refreshStorageUsageInBackground();
  }

  /// 컬렉션 내 클립 수 조회.
  Future<int> countClipsInCollection(int collectionId) async {
    return _clipRepository.countVisibleClipsInCollection(collectionId);
  }

  /// 이름 중복 검사 (같은 저장위치 탭의 그룹+콜렉션 안에서만 유일하면 됨).
  Future<bool> isNameExists(String name, {String? storageMode}) async {
    final mode = storageMode ?? _activeStorageMode;
    final groupMatch = await (db.select(db.groups)
          ..where((g) => g.name.equals(name) & g.storageMode.equals(mode)))
        .getSingleOrNull();
    if (groupMatch != null) return true;

    final collectionMatch = await (db.select(db.collections)
          ..where((c) => c.name.equals(name) & c.storageMode.equals(mode)))
        .getSingleOrNull();
    return collectionMatch != null;
  }

  /// 새 컬렉션 생성 후 목록 갱신. 서버/클라우드 탭이면 원격에도 독립 저장.
  Future<void> createCollection(String name) async {
    final groupIds = selectedGroupId != null && selectedGroupId != -1
        ? [selectedGroupId!]
        : const <int>[];
    final collection = await _libraryEntitySyncCoordinator.createCollection(
      name,
      _activeStorageMode,
      groupIds: groupIds,
    );

    if (groupIds.isNotEmpty) {
      await db.into(db.groupCollections).insert(
            GroupCollectionsCompanion.insert(
                groupId: groupIds.first, collectionId: collection.id),
          );
    }

    await selectGroup(selectedGroupId); // 현재 그룹의 콜렉션 다시 불러오기
  }

  /// 콜렉션 이름 변경 후 목록 갱신. 원격에 동기화된 콜렉션이면 원격도 갱신.
  Future<void> renameCollection(int id, String name) async {
    await _libraryEntitySyncCoordinator.renameCollection(id, name);
    await selectGroup(selectedGroupId);
  }

  /// 그룹으로 돌아감 (선택한 컬렉션 해제)
  void backToCollections() {
    closeCollectionMenu();
    selectedCollectionId = null;
    clips = [];
    clipItems = [];
    tagsByClip = {};
    notifyListeners();
  }

  /// 라이브러리 루트(그룹 목록)로 돌아감
  void backToGroups() {
    closeCollectionMenu();
    selectedGroupId = null;
    selectedCollectionId = null;
    collections = [];
    clips = [];
    clipItems = [];
    tagsByClip = {};
    loadGroups();
  }

  void _setGoogleDriveLinkState({
    required bool isRunning,
    required String message,
    required String? error,
  }) {
    _isGoogleDriveLinking = isRunning;
    _googleDriveLinkMessage = message;
    _googleDriveLinkError = error;
    if (isRunning && error == null) {
      AppLogger.d(
        '[Clip][Cloud] state=loading message=$message',
      );
    } else if (!isRunning && error == null) {
      AppLogger.d(
        '[Clip][Cloud] state=success message=$message',
      );
    } else if (!isRunning && error != null) {
      AppLogger.w(
        '[Clip][Cloud] state=failed message=$message error=$error',
      );
    }
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────
  // Internal helpers
  // ─────────────────────────────────────────────────────────────────

  Future<void> _buildClipItems() async {
    // 태그 매핑
    tagsByClip = {};
    if (clips.isNotEmpty) {
      final clipIds = clips.map((c) => c.id).toList();
      final jt = db.clipTags;
      final rows = await (db.select(db.tags).join([
        innerJoin(jt, jt.tagId.equalsExp(db.tags.id)),
      ])
            ..where(jt.clipId.isIn(clipIds)))
          .get();

      for (final row in rows) {
        final tag = row.readTable(db.tags);
        final ct = row.readTable(jt);
        tagsByClip.putIfAbsent(ct.clipId, () => []).add(tag);
      }
    }

    // ClipItem 구성 (segments + thumbnail)
    clipItems = [];
    final currentAccountId = fb.FirebaseAuth.instance.currentUser?.uid;
    for (final c in clips) {
      final segments = await (db.select(db.segments)
            ..where((s) => s.clipId.equals(c.id))
            ..orderBy([(s) => OrderingTerm.asc(s.startMs)]))
          .get();

      String resolvedPath = c.filePath;
      if (c.storageMode == ClipStorageConstants.storageModeLocal) {
        resolvedPath = c.sourceFilePath ?? c.filePath;
      } else if (currentAccountId != null) {
        // gdrive 클립의 캐시 엔트리는 ownerScope='cloud_account'로 저장되므로
        // storageMode에 맞춰 분기해야 한다. (server -> app_account)
        final cacheOwnerScope =
            c.storageMode == ClipStorageConstants.storageModeGoogleDrive
                ? ClipStorageConstants.ownerScopeCloudAccount
                : ClipStorageConstants.ownerScopeAppAccount;
        final cacheEntry = await (db.select(db.clipCacheEntries)
              ..where((entry) =>
                  entry.clipId.equals(c.id) &
                  entry.provider.equals(c.storageMode) &
                  entry.ownerScope.equals(cacheOwnerScope) &
                  entry.ownerKey.equals(currentAccountId))
              ..limit(1))
            .getSingleOrNull();
        if (cacheEntry != null) {
          resolvedPath = cacheEntry.filePath;
        }
      }

      // 썸네일은 항상 ClipService의 복구 로직을 사용한다.
      // (clip.thumbnailFilePath 로컬 캐시 -> 없으면 server/gdrive 원격 썸네일 다운로드)
      // 여기서 직접 VideoThumbnail로 재생성을 시도하면 gdrive처럼 로컬에
      // 원본 영상이 없는 클립은 썸네일을 영영 못 불러오는 문제가 재발한다.
      final thumbBytes = await _clipRepository.loadThumbnailBytes(c);
      clipItems.add(
        ClipItem(
          clip: c.copyWith(filePath: resolvedPath),
          tags: tagsByClip[c.id] ?? const [],
          segments: segments,
          thumbnail: thumbBytes,
        ),
      );
    }
  }

  /// 모든 콜렉션 조회 (관리 모달용, 현재 활성 저장위치 탭 기준)
  Future<List<Collection>> fetchAllCollections() async {
    return _collectionRepository.getAllVisibleCollections(_activeStorageMode);
  }

  /// 콜렉션의 매핑된 그룹 ID 목록 조회
  Future<List<int>> getGroupIdsForCollection(int collectionId) async {
    final query = db.select(db.groupCollections)
      ..where((gc) => gc.collectionId.equals(collectionId));
    final rows = await query.get();
    return rows.map((r) => r.groupId).toList();
  }

  /// 특정 그룹의 매핑된 콜렉션 ID 목록 조회
  Future<List<int>> getCollectionIdsForGroup(int groupId) async {
    final query = db.select(db.groupCollections)
      ..where((gc) => gc.groupId.equals(groupId));
    final rows = await query.get();
    return rows.map((r) => r.collectionId).toList();
  }

  /// 특정 콜렉션의 그룹 매핑 업데이트
  Future<void> updateGroupsForCollection(
      int collectionId, List<int> groupIds) async {
    await db.transaction(() async {
      await (db.delete(db.groupCollections)
            ..where((gc) => gc.collectionId.equals(collectionId)))
          .go();
      for (final gid in groupIds) {
        await db.into(db.groupCollections).insert(
              GroupCollectionsCompanion.insert(
                  groupId: gid, collectionId: collectionId),
            );
      }
    });
    // 현재 보고 있는 화면이 갱신되어야 할 수 있음
    await loadGroups();
    await selectGroup(selectedGroupId);
  }

  /// 특정 그룹의 콜렉션 매핑 업데이트
  Future<void> updateCollectionsForGroup(
      int groupId, List<int> collectionIds) async {
    await db.transaction(() async {
      await (db.delete(db.groupCollections)
            ..where((gc) => gc.groupId.equals(groupId)))
          .go();
      for (final cid in collectionIds) {
        await db.into(db.groupCollections).insert(
              GroupCollectionsCompanion.insert(
                  groupId: groupId, collectionId: cid),
            );
      }
    });
    // 현재 보고 있는 화면이 갱신되어야 할 수 있음
    await loadGroups();
    await selectGroup(selectedGroupId);
  }
}
