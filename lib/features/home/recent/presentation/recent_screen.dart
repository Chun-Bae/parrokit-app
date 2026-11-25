// ============================================================================
// lib/features/recent/presentation/recent_screen.dart
// ============================================================================
//
// [역할]
// 최근 본 클립 목록 화면.
// 사용자가 최근 시청한 클립들을 리스트로 표시.
//
// [레이어]
// Presentation Layer - View
//
// [구성 요소]
// - RecentClipCard: 클립 카드 위젯
// - RecentListSkeleton: 로딩 스켈레톤
// - EmptyRecentView: 빈 상태 표시
// ============================================================================

import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:parrokit/core/app/navigation/push_screen.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:provider/provider.dart';

import 'package:parrokit/core/state/provider/clip_activity_provider.dart';
import 'package:parrokit/features/collection/clip/player/presentation/clip_player_screen.dart';

import 'widgets/recent_clip_card.dart';
import 'widgets/recent_list_skeleton.dart';
import 'widgets/empty_recent_view.dart';

/// 최근 본 클립 목록 화면.
class RecentScreen extends StatefulWidget {
  const RecentScreen({super.key});

  @override
  State<RecentScreen> createState() => _RecentScreenState();
}

class _RecentScreenState extends State<RecentScreen> {
  // ─────────────────────────────────────────────────────────────────
  // State
  // ─────────────────────────────────────────────────────────────────

  late Future<List<(int, Uint8List?, String?, String?)>> _future;

  // ─────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  // ─────────────────────────────────────────────────────────────────
  // Data Loading
  // ─────────────────────────────────────────────────────────────────

  Future<List<(int, Uint8List?, String?, String?)>> _load({
    bool refreshThumb = false,
  }) {
    final provider = context.read<ClipActivityProvider>();
    return provider.fetchRecentClips(limit: 100, refreshThumb: refreshThumb);
  }

  Future<void> _onRefresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  // ─────────────────────────────────────────────────────────────────
  // Actions
  // ─────────────────────────────────────────────────────────────────

  void _openPlayer(int clipId) {
    pushAppScreen(
      context,
      ClipPlayerScreen(
        clipId: clipId,
        initialIndex: 0,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('최근 본 클립'),
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: FutureBuilder<List<(int, Uint8List?, String?, String?)>>(
          future: _future,
          builder: (context, snap) {
            // 로딩 중
            if (snap.connectionState == ConnectionState.waiting) {
              return const RecentListSkeleton();
            }

            // 에러
            if (snap.hasError) {
              AppLogger.e('[Recent] 최근 본 클립 읽기 실패', error: snap.error);
              // 전에는 '아래로 당겨 다시 시도해 주세요.'라고 적어 두고
              // 스크롤되지 않는 Center를 돌려줬다. 당길 수 없으니 말만
              // 그랬고 길이 없었다(5차 394). 당길 수 있게 만들고 단추도 둔다.
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.sectionGap),
                children: [
                  const SizedBox(height: 48),
                  // 내부 오류 글(snap.error)을 그대로 보여 주지 않는다(5차).
                  const Text(
                    '최근 본 클립을 불러오지 못했어요.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: OutlinedButton(
                      key: const ValueKey('recent-retry'),
                      onPressed: _onRefresh,
                      child: const Text('다시 시도'),
                    ),
                  ),
                ],
              );
            }

            // 빈 상태
            final items = snap.data ?? const [];
            if (items.isEmpty) {
              return const EmptyRecentView();
            }

            // 리스트
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              itemCount: items.length,
              separatorBuilder: (_, __) => Divider(
                height: 8,
                thickness: 0.5,
                color: cs.outlineVariant.withValues(alpha: .6),
              ),
              itemBuilder: (context, index) {
                final (clipId, thumb, clipTitle, titleName) = items[index];
                return RecentClipCard(
                  clipId: clipId,
                  thumb: thumb,
                  clipTitle: clipTitle ?? '제목 없음',
                  titleName: titleName,
                  onTap: () => _openPlayer(clipId),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
