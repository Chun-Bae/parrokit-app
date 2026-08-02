import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/state/provider/clip_provider.dart';

/// 클립을 로컬/서버/Google Drive 사이로 옮기는 동안 다른 조작을 막고
/// 진행 과정을 보여주는 전체 화면 오버레이. 단일 클립 이동과 다중 선택
/// 이동이 이 위젯 하나를 함께 사용합니다.
///
/// `ClipProvider`의 저장위치 이동 상태를 직접 watch하므로, 표시 여부와
/// 내용을 별도 인자로 받지 않습니다.
class StorageTransferOverlay extends StatelessWidget {
  const StorageTransferOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final clipProvider = context.watch<ClipProvider>();
    if (!clipProvider.shouldShowStorageTransferOverlay) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: _StorageTransferCard(
                title: clipProvider.storageTransferTitle,
                message: clipProvider.storageTransferMessage,
                progress: clipProvider.storageTransferProgress,
                total: clipProvider.storageTransferTotal,
                isRunning: clipProvider.isStorageTransferRunning,
                succeeded: clipProvider.storageTransferSucceeded,
                error: clipProvider.storageTransferError,
                onDismissError: clipProvider.dismissStorageTransferError,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StorageTransferCard extends StatelessWidget {
  const _StorageTransferCard({
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
