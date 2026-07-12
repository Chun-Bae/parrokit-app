// ============================================================================
// lib/core/app.dart
// ============================================================================
//
// [역할]
// 앱 루트 위젯.
// MaterialApp 설정 및 테마/라우터 구성.
//
// [레이어]
// Core Layer
// ============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/state/provider/clip_provider.dart';
import 'package:parrokit/core/state/provider/theme_provider.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/core/shared/theme/app_theme.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class App extends StatefulWidget {
  const App({super.key, required this.router});

  final GoRouter router;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  String? _remoteClipsSyncedUid;

  /// 로그인(계정 전환 포함) 직후 1회, 서버/클라우드로 옮겨진 클립 중 이
  /// 기기에 없는 것을 받아옵니다. 클라우드는 연동돼 있지 않으면 조용히
  /// 아무것도 하지 않습니다.
  void _syncRemoteClipsOnLoginIfNeeded(UserProvider userProvider) {
    final uid = userProvider.isLoggedIn ? userProvider.currentUser?.id : null;
    if (uid == null) {
      _remoteClipsSyncedUid = null;
      return;
    }
    if (_remoteClipsSyncedUid == uid) return;
    _remoteClipsSyncedUid = uid;

    final clipProvider = context.read<ClipProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      clipProvider.pullRemoteServerClips();
      clipProvider.pullRemoteCloudClips();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final userProvider = context.watch<UserProvider>();
    final clipProvider = context.watch<ClipProvider>();

    _syncRemoteClipsOnLoginIfNeeded(userProvider);

    return MaterialApp.router(
      title: 'Parrokit',
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: theme.themeMode,
      routerConfig: widget.router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return Stack(
          children: [
            Positioned.fill(child: child ?? const SizedBox.shrink()),
            if (clipProvider.shouldShowStorageTransferOverlay)
              Positioned.fill(
                child: Material(
                  color: Colors.black.withValues(alpha: 0.45),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 340),
                        child: _StorageTransferOverlay(
                          title: clipProvider.storageTransferTitle,
                          message: clipProvider.storageTransferMessage,
                          progress: clipProvider.storageTransferProgress,
                          total: clipProvider.storageTransferTotal,
                          isRunning: clipProvider.isStorageTransferRunning,
                          succeeded: clipProvider.storageTransferSucceeded,
                          error: clipProvider.storageTransferError,
                          onDismissError:
                              clipProvider.dismissStorageTransferError,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 클립을 로컬/서버/Google Drive 사이로 옮기는 동안 다른 조작을 막고
/// 진행 과정을 보여주는 전체 화면 오버레이. 단일 클립 이동과 다중 선택
/// 이동이 이 위젯 하나를 함께 사용합니다.
class _StorageTransferOverlay extends StatelessWidget {
  const _StorageTransferOverlay({
    required this.title,
    required this.message,
    required this.progress,
    required this.total,
    required this.isRunning,
    required this.succeeded,
    required this.error,
    required this.onDismissError,
  });

  final String title;
  final String message;
  final int progress;
  final int total;
  final bool isRunning;
  final bool succeeded;
  final String? error;
  final VoidCallback onDismissError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isError = error != null;
    final progressValue = total > 0 ? (progress / total).clamp(0.0, 1.0) : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: DecoratedBox(
        decoration: BoxDecoration(color: colorScheme.surface),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: isError
                    ? Icon(
                        Icons.error_outline_rounded,
                        color: colorScheme.error,
                        size: 36,
                      )
                    : succeeded
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: colorScheme.primary,
                            size: 36,
                          )
                        : CircularProgressIndicator(
                            strokeWidth: 3,
                            value: progressValue,
                          ),
              ),
              const SizedBox(height: 16),
              Text(
                isError ? '문제가 생겼어요' : title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                isError ? error! : message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              if (!isError && isRunning && total > 0) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: progressValue,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${((progressValue ?? 0) * 100).round()}%',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
              if (isError) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onDismissError,
                    child: const Text('확인'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
