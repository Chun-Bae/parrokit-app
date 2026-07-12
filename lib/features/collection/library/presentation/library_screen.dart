// ============================================================================
// lib/features/_content/library/presentation/library_screen.dart
// ============================================================================
//
// [역할]
// 라이브러리 메인 화면 (폴더/태그 탭 전환)
//
// [레이어]
// Presentation Layer > Screen
//
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/domain/collection_clip/data/constants/clip_storage_constants.dart';
import 'package:parrokit/core/state/provider/clip_provider.dart';
import 'package:parrokit/features/collection/library/presentation/providers/tag_filter_provider.dart';
import 'package:parrokit/data/local/app_database.dart'; // Tag definition

import '../domain/library_mode.dart';
import 'sections/library_folder_section.dart';
import 'sections/library_tag_section.dart';
import 'widgets/bookmark_tabs.dart';
import 'widgets/storage_scope_tabs.dart';

/// [역할]
/// 라이브러리 메인 화면.
///
/// '폴더(Collections)별 보기'와 '태그별 보기' 두 가지 모드를 제공합니다.
/// 상단 [BookmarkTabs]를 통해 모드를 전환할 수 있습니다.
///
/// [기능]
/// - [LibraryTab.folder]: [LibraryFolderSection] 표시 (컬렉션 → 클립)
/// - [LibraryTab.tag]: [LibraryTagSection] 표시 (태그 기반 필터링 및 검색)
/// - 초기 진입 시 특정 Collection으로 바로 이동 가능 ([initialCollectionId])
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    this.initialCollectionId,
    this.initialTab,
    this.initialStorageMode,
  });

  /// 초기 선택할 Collection ID (옵션)
  final int? initialCollectionId;

  /// 초기 활성화할 탭 인덱스 (0: Folder, 1: Tag)
  final int? initialTab;

  /// 초기 활성화할 저장위치 탭 (로컬/서버/클라우드, 옵션)
  final String? initialStorageMode;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  LibraryTab tab = LibraryTab.folder;
  late String _storageMode;

  static const _validStorageModes = {
    ClipStorageConstants.storageModeLocal,
    ClipStorageConstants.storageModeServer,
    ClipStorageConstants.storageModeGoogleDrive,
  };

  @override
  void initState() {
    super.initState();
    tab = widget.initialTab == 1 ? LibraryTab.tag : LibraryTab.folder;
    _storageMode = _validStorageModes.contains(widget.initialStorageMode)
        ? widget.initialStorageMode!
        : ClipStorageConstants.storageModeLocal;
    // 딥링크 등으로 곧장 서버 탭이 지정돼도 잠금 중에는 로컬로 대체한다.
    if (_storageMode == ClipStorageConstants.storageModeServer &&
        ClipStorageConstants.isServerStorageLocked) {
      _storageMode = ClipStorageConstants.storageModeLocal;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final clipProvider = context.read<ClipProvider>();
      final tagProv = context.read<TagFilterProvider>();

      await tagProv.startWatching();
      clipProvider.startWatchingDistinctTags();

      await clipProvider.setActiveStorageMode(_storageMode);
      if (widget.initialCollectionId != null) {
        await clipProvider.loadCollections();
        await clipProvider.selectCollection(widget.initialCollectionId);
      }
    });
  }

  void _onStorageModeChanged(String mode) {
    if (_storageMode == mode) return;
    setState(() => _storageMode = mode);
    context.read<ClipProvider>().setActiveStorageMode(mode);
  }

  // --- Tag Logic (Provider 위임) ---

  void _onTagSelected(Tag t) {
    context.read<TagFilterProvider>().addTag(t.name);
  }

  void _onTagDeleted(String name) {
    context.read<TagFilterProvider>().removeTag(name);
  }

  void _onSelectAllTags() {
    final clipProvider = context.read<ClipProvider>();
    if (clipProvider.distinctTags.isEmpty) return;

    context.read<TagFilterProvider>().setTags(
          clipProvider.distinctTags.map((t) => t.name),
        );
  }

  void _onClearResult() {
    context.read<TagFilterProvider>().clearTags();
  }

  /// 현재 저장위치 탭에 맞는 pull sync를 실행합니다. 로컬 탭은 당길 게
  /// 없으므로 build()에서 애초에 RefreshIndicator를 안 붙입니다.
  Future<void> _onRefreshRemoteClips() async {
    final clipProvider = context.read<ClipProvider>();
    if (_storageMode == ClipStorageConstants.storageModeServer) {
      await clipProvider.pullRemoteServerClips();
    } else if (_storageMode == ClipStorageConstants.storageModeGoogleDrive) {
      await clipProvider.pullRemoteCloudClips();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final clipProvider = context.watch<ClipProvider>();
    final tagProv = context.watch<TagFilterProvider>();
    final isSelectionMode = clipProvider.isCollectionMenuOpen &&
        clipProvider.selectedCollectionId != null;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            if (!isSelectionMode) ...[
              const SizedBox(height: 8),
              StorageScopeTabs(
                value: _storageMode,
                onChanged: _onStorageModeChanged,
              ),
              const SizedBox(height: 8),
              BookmarkTabs(
                value: tab,
                onChanged: (v) => setState(() => tab = v),
              ),
              const SizedBox(height: 10),
            ],
            Expanded(
              child: tab == LibraryTab.folder
                  ? (_storageMode == ClipStorageConstants.storageModeLocal
                      ? const LibraryFolderSection()
                      : RefreshIndicator(
                          onRefresh: _onRefreshRemoteClips,
                          child: const LibraryFolderSection(),
                        ))
                  : LibraryTagSection(
                      allTags: clipProvider.distinctTags,
                      selectedTags: tagProv.activeTagNames.toSet(),
                      onTagSelected: _onTagSelected,
                      onTagDeleted: _onTagDeleted,
                      onSelectAll: _onSelectAllTags,
                      onClearResult: _onClearResult,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
