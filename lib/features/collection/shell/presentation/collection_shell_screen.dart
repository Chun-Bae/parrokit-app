import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:parrokit/core/domain/collection_clip/data/constants/clip_storage_constants.dart';
import 'package:parrokit/core/state/provider/clip_provider.dart';
import 'package:parrokit/data/local/app_database.dart';
import 'package:parrokit/features/collection/library/domain/library_mode.dart';
import 'package:parrokit/features/collection/library/presentation/providers/tag_filter_provider.dart';
import 'package:parrokit/features/collection/library/presentation/sections/library_folder_section.dart';
import 'package:parrokit/features/collection/library/presentation/sections/library_tag_section.dart';
import 'package:parrokit/features/collection/library/presentation/widgets/bookmark_tabs.dart';
import 'package:parrokit/features/collection/library/presentation/widgets/storage_scope_tabs.dart';

import 'widgets/sentence_collection_preview.dart';
import 'widgets/word_collection_preview.dart';

class CollectionShellScreen extends StatefulWidget {
  const CollectionShellScreen({super.key});

  @override
  State<CollectionShellScreen> createState() => _CollectionShellScreenState();
}

class _CollectionShellScreenState extends State<CollectionShellScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  LibraryTab _clipView = LibraryTab.folder;
  String _storageMode = ClipStorageConstants.storageModeLocal;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final clipProvider = context.read<ClipProvider>();
      final tagProvider = context.read<TagFilterProvider>();

      await tagProvider.startWatching();
      if (!mounted) return;
      clipProvider.startWatchingDistinctTags();
      await clipProvider.setActiveStorageMode(_storageMode);
    });
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging || !mounted) return;
    setState(() {});
    if (_tabController.index != 1) {
      context.read<ClipProvider>().closeCollectionMenu();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onStorageModeChanged(String mode) {
    if (_storageMode == mode) return;
    setState(() => _storageMode = mode);
    context.read<ClipProvider>().setActiveStorageMode(mode);
  }

  void _onTagSelected(Tag tag) =>
      context.read<TagFilterProvider>().addTag(tag.name);

  void _onTagDeleted(String name) =>
      context.read<TagFilterProvider>().removeTag(name);

  void _onSelectAllTags() {
    final clipProvider = context.read<ClipProvider>();
    if (clipProvider.distinctTags.isEmpty) return;
    context.read<TagFilterProvider>().setTags(
          clipProvider.distinctTags.map((tag) => tag.name),
        );
  }

  void _onClearResult() => context.read<TagFilterProvider>().clearTags();

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
    final colors = Theme.of(context).colorScheme;
    final clipProvider = context.watch<ClipProvider>();
    final tagProvider = context.watch<TagFilterProvider>();
    final isClipTab = _tabController.index == 1;
    final isClipSelectionMode = isClipTab && clipProvider.isCollectionMenuOpen;
    final isCollectionSelectionMode =
        isClipSelectionMode && clipProvider.selectedCollectionId != null;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(
              context,
              clipProvider,
              isSelectionMode: isClipSelectionMode,
            ),
            if (!isClipSelectionMode) ...[
              _buildOverview(context, clipProvider.clipItems.length),
              const SizedBox(height: 14),
              _buildCollectionTabs(context),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  const SentenceCollectionPreview(),
                  _buildClipPage(
                    context,
                    clipProvider,
                    tagProvider,
                    hideControls: isCollectionSelectionMode,
                  ),
                  const WordCollectionPreview(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    ClipProvider clipProvider, {
    required bool isSelectionMode,
  }) {
    final selectedCount = clipProvider.selectedClipIds.length;
    final visibleClipIds =
        clipProvider.clipItems.map((item) => item.clip.id).toSet();
    final isAllSelected =
        visibleClipIds.isNotEmpty && visibleClipIds.length == selectedCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 10, 4),
      child: Row(
        children: [
          if (isSelectionMode)
            IconButton(
              tooltip: '선택 닫기',
              onPressed: clipProvider.closeCollectionMenu,
              icon: const Icon(Icons.close_rounded),
            ),
          Expanded(
            child: Text(
              isSelectionMode ? '$selectedCount개 선택' : '콜렉션',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.7,
                  ),
            ),
          ),
          if (isSelectionMode)
            TextButton(
              onPressed: visibleClipIds.isEmpty
                  ? null
                  : () {
                      if (isAllSelected) {
                        clipProvider.clearClipSelection();
                      } else {
                        clipProvider.selectAllVisibleClips();
                      }
                    },
              child: Text(isAllSelected ? '전체 해제' : '전체 선택'),
            )
          else ...[
            IconButton.filledTonal(
              tooltip: '콜렉션 검색',
              onPressed: () => _showSearchSheet(context),
              icon: const Icon(Icons.search_rounded),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              tooltip: '새 항목 추가',
              onPressed: () => _showAddSheet(context),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOverview(BuildContext context, int clipCount) {
    final colors = Theme.of(context).colorScheme;
    final pages = [
      (
        icon: Icons.format_quote_rounded,
        title: '모아둔 문장을 바로 연습해요',
        detail: '공식 문장팩과 사람들이 공유한 표현을 둘러보세요',
        color: const Color(0xFFDDEFEA),
      ),
      (
        icon: Icons.video_library_rounded,
        title: '클립 $clipCount개를 보관 중이에요',
        detail: '영상의 장면과 문장을 함께 기억할 수 있어요',
        color: const Color(0xFFDCE9F8),
      ),
      (
        icon: Icons.spellcheck_rounded,
        title: '문장에서 만난 단어를 모아요',
        detail: '따로 외우기보다 실제 표현과 함께 복습해요',
        color: const Color(0xFFFFE8C7),
      ),
    ];
    final page = pages[_tabController.index];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: Container(
          key: ValueKey(_tabController.index),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 17, 16, 17),
          decoration: BoxDecoration(
            color: page.color,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.82),
                  shape: BoxShape.circle,
                ),
                child: Icon(page.icon, color: const Color(0xFF42636A)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      page.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      page.detail,
                      style: TextStyle(
                        color: colors.onSurface.withValues(alpha: 0.66),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollectionTabs(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 62,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(20),
        ),
        child: TabBar(
          controller: _tabController,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          labelColor: colors.onSurface,
          unselectedLabelColor: colors.onSurfaceVariant,
          labelStyle: const TextStyle(fontWeight: FontWeight.w900),
          tabs: const [
            Tab(icon: Icon(Icons.format_quote_rounded, size: 18), text: '문장'),
            Tab(icon: Icon(Icons.smart_display_rounded, size: 18), text: '클립'),
            Tab(icon: Icon(Icons.spellcheck_rounded, size: 18), text: '단어'),
          ],
        ),
      ),
    );
  }

  Widget _buildClipPage(
    BuildContext context,
    ClipProvider clipProvider,
    TagFilterProvider tagProvider, {
    required bool hideControls,
  }) {
    return Column(
      children: [
        if (!hideControls) ...[
          const SizedBox(height: 8),
          StorageScopeTabs(
            value: _storageMode,
            onChanged: _onStorageModeChanged,
          ),
          const SizedBox(height: 8),
          BookmarkTabs(
            value: _clipView,
            onChanged: (value) => setState(() => _clipView = value),
          ),
          const SizedBox(height: 4),
        ],
        Expanded(
          child: _buildClipContent(context, clipProvider, tagProvider),
        ),
      ],
    );
  }

  Widget _buildClipContent(
    BuildContext context,
    ClipProvider clipProvider,
    TagFilterProvider tagProvider,
  ) {
    if (_clipView == LibraryTab.tag) {
      return LibraryTagSection(
        allTags: clipProvider.distinctTags,
        selectedTags: tagProvider.activeTagNames.toSet(),
        onTagSelected: _onTagSelected,
        onTagDeleted: _onTagDeleted,
        onSelectAll: _onSelectAllTags,
        onClearResult: _onClearResult,
      );
    }

    if (_storageMode == ClipStorageConstants.storageModeLocal) {
      return const LibraryFolderSection();
    }

    return RefreshIndicator(
      onRefresh: _onRefreshRemoteClips,
      child: const LibraryFolderSection(),
    );
  }

  Future<void> _showSearchSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          14,
          20,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(sheetContext).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '콜렉션 검색',
              style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 14),
            const TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: '문장, 단어, 클립 검색',
                prefixIcon: Icon(Icons.search_rounded),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                child: Text(
                  '새 학습 재료',
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              _AddMaterialTile(
                icon: Icons.format_quote_rounded,
                title: '문장 추가',
                subtitle: '직접 쓰거나 문장팩에서 골라요',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _tabController.animateTo(0);
                },
              ),
              _AddMaterialTile(
                icon: Icons.smart_display_rounded,
                title: '클립 추가',
                subtitle: '영상과 자막을 함께 보관해요',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _tabController.animateTo(1);
                },
              ),
              _AddMaterialTile(
                icon: Icons.spellcheck_rounded,
                title: '단어 추가',
                subtitle: '문장 속 표현을 따로 표시해요',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _tabController.animateTo(2);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddMaterialTile extends StatelessWidget {
  const _AddMaterialTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
        child: Icon(icon),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}
