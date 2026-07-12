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
import 'package:go_router/go_router.dart';
import 'package:parrokit/core/app/navigation/app_bottom_navbar.dart';
import 'package:parrokit/core/app/router/app_routes.dart';
import 'package:parrokit/core/state/provider/clip_provider.dart';
import 'package:parrokit/features/collection/library/presentation/widgets/storage_transfer_sheet.dart';
import 'package:provider/provider.dart';

/// 앱 메인 쉘 위젯.
///
/// 바텀 네비게이션 바를 포함한 레이아웃.
/// 특정 경로(`/clips/...`, `/recents`)에서는 네비바 숨김.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  /// 현재 경로에서 탭 인덱스 계산
  int _indexFromLocation(String location) {
    if (location.startsWith(AppRoutes.communityPath)) return 1;
    if (location.startsWith(AppRoutes.explorePath)) return 2;
    if (location.startsWith(AppRoutes.collectionPath)) return 3;
    if (location.startsWith(AppRoutes.morePath)) return 4;
    return 0; // dashboard
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _indexFromLocation(location);
    final clipProvider = context.watch<ClipProvider>();

    // 네비바 숨김 조건
    final hideNav = location.startsWith('/clips/') ||
        location == AppRoutes.recentsPath ||
        location == AppRoutes.contentStudioBridgePath ||
        location.startsWith('${AppRoutes.contentStudioBridgePath}/');
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
      bottomNavigationBar: hideNav
          ? null
          : showCollectionSelectionBar
              ? _buildCollectionSelectionBar(context)
              : AppBottomNavBar(
                  currentIndex: currentIndex,
                  onTap: (i) => _onTabTap(context, i),
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
        borderRadius: BorderRadius.circular(20),
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
        borderRadius: BorderRadius.circular(20),
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
                    tooltip: '전환',
                    icon: const Icon(Icons.swap_horiz_rounded),
                    onPressed: selectedClipIds.isEmpty
                        ? null
                        : () async {
                            final target = await showStorageTransferSheet(
                              context,
                              title: '선택한 ${selectedClipIds.length}개 클립 전환',
                              subtitle:
                                  '선택한 클립 ${selectedClipIds.length}개를 한 번에 옮길 위치를 고르세요.',
                              hasGoogleDriveLinked:
                                  clipProvider.hasGoogleDriveLinked,
                            );

                            if (!context.mounted || target == null) return;

                            await clipProvider.moveClipsToStorage(
                              selectedClipIds,
                              target,
                            );
                            if (!context.mounted) return;
                            clipProvider.closeCollectionMenu();
                          },
                  ),
                  IconButton(
                    tooltip: '삭제',
                    icon: const Icon(Icons.delete_rounded),
                    onPressed: selectedClipIds.isEmpty
                        ? null
                        : () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              barrierDismissible: false,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text('선택한 클립을 삭제할까요?'),
                                content: Text(
                                  '선택한 클립 ${selectedClipIds.length}개를 삭제합니다.\n\n'
                                  '삭제한 클립은 다시 되돌릴 수 없습니다.',
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
                                    child: const Text('삭제'),
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

  /// 탭 선택 시 네비게이션
  void _onTabTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.dashboardPath);
        break;
      case 1:
        context.go(AppRoutes.communityPath);
        break;
      case 2:
        context.go(AppRoutes.explorePath);
        break;
      case 3:
        context.go(AppRoutes.collectionPath);
        break;
      case 4:
        context.go(AppRoutes.morePath);
        break;
    }
  }
}
