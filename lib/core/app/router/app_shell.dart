// ============================================================================
// lib/core/router/app_shell.dart
// ============================================================================
//
// [역할]
// 앱 메인 쉘 위젯.
// 바텀 네비게이션 바를 포함한 레이아웃 쉘.
// 특정 경로에서는 네비바 숨김.
//
// [레이어]
// Core Layer > Router
// ============================================================================

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:parrokit/features/collection/clip/player/presentation/widgets/listening_bar.dart';
import 'package:parrokit/core/state/provider/background_playback_provider.dart';
import 'package:parrokit/core/state/provider/clip_playback_holder.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/core/domain/collection_clip/data/constants/clip_storage_constants.dart';
import 'package:parrokit/features/collection/library/presentation/widgets/clip_backup_action.dart';
import 'package:go_router/go_router.dart';
import 'package:parrokit/core/app/navigation/app_bottom_navbar.dart';
import 'package:parrokit/core/app/router/app_routes.dart';
import 'package:parrokit/core/app/router/tab_reselect.dart';
import 'package:parrokit/core/state/provider/clip_provider.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/widgets/app_bottom_sheet.dart';

/// 앱 메인 쉘 위젯.
///
/// 바텀 네비게이션 바를 포함한 레이아웃.
/// 특정 경로(`/clips/...`, `/recents`)에서는 네비바 숨김.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = appShellTabIndex(location);
    final clipProvider = context.watch<ClipProvider>();

    // 네비바 숨김 조건
    final hideNav = appShellHidesNavBar(location);
    // 플레이어 화면에서는 '듣는 중' 줄을 띄우지 않는다. 새 플레이어는 화면을
    // 나가도 살아 있어서, 돌아왔을 때 줄이 겹쳐 보였다(5차 4단계).
    final onPlayer = appShellHidesListeningBar(location);
    final isCollectionRoute = location.startsWith(AppRoutes.collectionPath);
    final showCollectionSelectionBar = isCollectionRoute &&
        clipProvider.isCollectionMenuOpen &&
        clipProvider.selectedCollectionId != null;

    return Scaffold(
      extendBody: true,
      // 저장위치 이동 중 전체 화면 차단 오버레이는 app.dart에서 전역으로
      // 그려진다 (바텀 네비게이션 바까지 함께 막기 위해 Scaffold 바깥
      // 레벨에 위치).
      body: child,
      // 모달 시트는 useRootNavigator로 띄워서 이 네비바 위를 덮는다.
      bottomNavigationBar: hideNav
          ? _listeningBar(context, onPlayer: onPlayer)
          : showCollectionSelectionBar
              ? _buildCollectionSelectionBar(context)
              // 시트가 떠 있는 동안에는 숨긴다. 네이티브 탭 바가 자기 프레임
              // 위로 드리우는 그림자가 시트 위에 가로 띠로 비쳤다(5차).
              // 자리는 그대로 두어(maintainSize) 본문이 움찔거리지 않는다.
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  // 플레이어를 나와도 듣고 있으면 무엇이 울리는지 알린다(5차).
                  _listeningBar(context, onPlayer: onPlayer),
                  ValueListenableBuilder<int>(
                    valueListenable: openAppSheetCount,
                    builder: (context, sheets, child) => Visibility(
                      visible: sheets == 0,
                      maintainState: true,
                      maintainAnimation: true,
                      maintainSize: true,
                      maintainInteractivity: false,
                      child: child!,
                    ),
                    child: AppBottomNavBar(
                      currentIndex: currentIndex,
                      onTap: (i) => _onTabTap(context, i,
                          currentIndex: currentIndex,
                          currentPath: GoRouterState.of(context).uri.path),
                    ),
                  ),
                ]),
    );
  }

  /// 듣는 중이면 줄을 그리고, 아니면 자리를 차지하지 않는다.
  Widget _listeningBar(BuildContext context, {bool onPlayer = false}) {
    // 새 플레이어로 듣는 중이면 그쪽을 보여 준다. 플레이어가 하나뿐이라
    // 넘기지 않고 그대로 돌고 있다(5차 4단계).
    final held = context.watch<ClipPlaybackHolder>();
    if (held.isActive && !onPlayer) {
      return _bar(
        context,
        playback: BackgroundPlayback(
          clipId: held.clipId!,
          title: held.title.isEmpty ? '클립' : held.title,
          playing: held.isPlaying,
        ),
        onTogglePlay: () => held.isPlaying ? held.pause() : held.resume(),
        onClose: held.stop,
      );
    }

    final playback = context.watch<BackgroundPlaybackProvider>();
    final current = playback.current;
    if (current == null) return const SizedBox.shrink();
    return _bar(
      context,
      playback: current,
      onTogglePlay: () =>
          current.playing ? playback.pause() : playback.resume(),
      onClose: playback.stop,
    );
  }

  Widget _bar(
    BuildContext context, {
    required BackgroundPlayback playback,
    required VoidCallback onTogglePlay,
    required VoidCallback onClose,
  }) {
    final current = playback;
    return SafeArea(
      top: false,
      bottom: false,
      child: ListeningBar(
        playback: current,
        onOpen: () => context.push(
            '${AppRoutes.clipsPath}/${AppRoutes.clipsPlayPath}'
            '?clipId=${current.clipId}'),
        onTogglePlay: onTogglePlay,
        onClose: onClose,
      ),
    );
  }

  Widget _buildCollectionSelectionBar(BuildContext context) {
    final clipProvider = context.read<ClipProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final selectedClipIds = clipProvider.selectedClipIds.toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 40),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.82),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    // 위치를 고르지 않는다. 구독 중이면 서버에 백업한다(5차 5단계).
                    tooltip: '백업',
                    icon: const Icon(Icons.backup_rounded),
                    onPressed: selectedClipIds.isEmpty
                        ? null
                        : () async {
                            if (!ensureBackupAllowed(context)) return;
                            final count = selectedClipIds.length;
                            await clipProvider.moveClipsToStorage(
                              selectedClipIds,
                              ClipStorageConstants.storageModeServer,
                            );
                            if (!context.mounted) return;
                            showToast(backupDoneMessage(count));
                            clipProvider.closeCollectionMenu();
                          },
                  ),
                  IconButton(
                    tooltip: '지우기',
                    icon: const Icon(Icons.delete_rounded),
                    onPressed: selectedClipIds.isEmpty
                        ? null
                        : () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              barrierDismissible: false,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text('선택한 클립을 지울까요?'),
                                content: Text(
                                  '선택한 클립 ${selectedClipIds.length}개를 지워요.\n\n'
                                  '지우면 되돌릴 수 없어요.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, false),
                                    child: const Text('취소'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, true),
                                    child: const Text('지우기'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed != true) return;

                            await clipProvider.deleteClipsById(selectedClipIds);
                            clipProvider.closeCollectionMenu();
                          },
                  ),
                  IconButton(
                    tooltip: '닫기',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: clipProvider.closeCollectionMenu,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 탭 선택 시 네비게이션.
  ///
  /// 이미 그 탭의 첫 화면에 있으면 화면을 다시 만들지 않고 [TabReselect]로
  /// 알려 맨 위로 스크롤하게 한다. 하위 화면이면 그 탭의 첫 화면으로 간다.
  void _onTabTap(BuildContext context, int index,
      {required int currentIndex, required String currentPath}) {
    final action = tabTapAction(
      index: index,
      currentIndex: currentIndex,
      currentPath: currentPath,
    );
    switch (action) {
      case TabTapAction.reselect:
        TabReselect.instance.fire(index);
      case TabTapAction.goToRoot:
        context.go(tabRootPath(index));
    }
  }
}

/// 탭의 첫 화면 경로. 번호는 AppShell·AppBottomNavBar와 같다
/// (0 쇼츠, 1 커뮤니티, 2 홈, 3 보관함, 4 더보기).
const tabRootPaths = [
  AppRoutes.explorePath,
  AppRoutes.communityPath,
  AppRoutes.dashboardPath,
  AppRoutes.collectionPath,
  AppRoutes.morePath,
];

/// 모르는 번호는 홈으로 둔다.
String tabRootPath(int index) => index >= 0 && index < tabRootPaths.length
    ? tabRootPaths[index]
    : AppRoutes.dashboardPath;

/// 탭을 눌렀을 때 할 일.
enum TabTapAction {
  /// 이미 그 탭의 첫 화면이다. 맨 위로 스크롤만 한다.
  reselect,

  /// 그 탭의 첫 화면으로 간다.
  goToRoot,
}

TabTapAction tabTapAction({
  required int index,
  required int currentIndex,
  required String currentPath,
}) =>
    index == currentIndex && currentPath == tabRootPath(index)
        ? TabTapAction.reselect
        : TabTapAction.goToRoot;

/// 지금 경로에서 아래 탭 바의 몇 번째 칸이 켜져 보일지.
int appShellTabIndex(String location) {
  if (location.startsWith(AppRoutes.communityPath)) return 1;
  if (location.startsWith(AppRoutes.explorePath)) return 0;
  if (location.startsWith(AppRoutes.collectionPath)) return 3;
  if (location.startsWith(AppRoutes.morePath)) return 4;
  return 2; // 홈
}

/// 이 경로에서 아래 탭 바를 숨기는지. 바텀시트가 탭 바를 피해 뜨려면
/// (app_bottom_sheet.dart) 탭 바가 있는지 알아야 해서 따로 뺐다.
/// 이 경로에서 '듣는 중' 줄을 숨기는지.
///
/// 새 플레이어는 화면을 나가도 살아 있어서, 플레이어와 편집 화면에서도 줄이
/// 떴다. 거기서는 영상이 눈앞에 있으니 줄이 필요 없다(5차 4단계).
bool appShellHidesListeningBar(String location) =>
    location.contains(AppRoutes.clipsPlayPath) ||
    location.contains('/${AppRoutes.clipsEditPath}');

bool appShellHidesNavBar(String location) =>
    location.startsWith('/clips/') ||
    location == AppRoutes.recentsPath ||
    location == AppRoutes.contentStudioBridgePath ||
    location.startsWith('${AppRoutes.contentStudioBridgePath}/');
