// ============================================================================
// lib/features/settings/more/presentation/sections/storage_section.dart
// ============================================================================
//
// [역할]
// 기기 안에 남겨둘 저장 공간을 조절하는 섹션.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:parrokit/core/app/router/app_routes.dart';
import 'package:parrokit/core/state/provider/clip_provider.dart';
import 'package:provider/provider.dart';
import '../widgets/card_container.dart';
import '../widgets/section_title.dart';

class StorageSection extends StatefulWidget {
  const StorageSection({super.key});

  @override
  State<StorageSection> createState() => _StorageSectionState();
}

class _StorageSectionState extends State<StorageSection> {
  @override
  void initState() {
    super.initState();
    // 캐시 관리 화면을 한 번 열어야만 숫자가 최신으로 보이던 문제 — 이
    // 섹션이 보이는 시점에 바로 최신 값을 받아오도록 한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ClipProvider>().refreshStorageUsage();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<ClipProvider>(
      builder: (context, clipProvider, _) {
        final cachedCount = clipProvider.cachedRemoteClipCount;
        final cachedBytes = clipProvider.cachedRemoteStorageUsedBytes;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('저장 공간'),
            const SizedBox(height: 10),
            CardContainer(
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  context.pushNamed(AppRoutes.storageCacheManagement);
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '기기 안에 남겨둘 공간',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '$cachedCount개 · ${_formatBytes(cachedBytes)}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const _BulletText(
                      text: '처음 본 원격 저장소의 동영상은 기기에 자동 보관되어 다음 재생이 더 빨라져요.',
                    ),
                    const SizedBox(height: 6),
                    const _BulletText(
                      text: '매번 다시 받지 않도록 자주 쓰는 동영상은 기기에 남겨두는 게 좋아요.',
                    ),
                    const SizedBox(height: 6),
                    const _BulletText(
                      text: '공간이 부족하면 오래 안 쓴 것부터 정리할 수 있도록 해놨어요.',
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          '캐시 관리 열기',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    return '${value.toStringAsFixed(value >= 10 || unitIndex == 0 ? 0 : 1)} ${units[unitIndex]}';
  }
}

class _BulletText extends StatelessWidget {
  const _BulletText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '•',
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}
