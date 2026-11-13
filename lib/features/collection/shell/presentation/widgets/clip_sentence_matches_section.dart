import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/app/router/app_routes.dart';
import 'package:parrokit/core/content/clip_sentence_match.dart';
import 'package:parrokit/core/content/db_clip_segment_source.dart';
import 'package:parrokit/core/state/provider/clip_provider.dart';
import 'package:parrokit/data/local/app_database.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';

/// 문장 상세에서 이 문장이 나오는 클립 자막을 찾아 보여주는 구역.
class ClipSentenceMatchesSection extends StatefulWidget {
  const ClipSentenceMatchesSection({
    super.key,
    required this.sentence,
    this.finder,
  });

  final String sentence;

  /// 비우면 기기 클립 DB에서 찾는다(앱에 클립 DB가 있을 때).
  final ClipSentenceFinder? finder;

  @override
  State<ClipSentenceMatchesSection> createState() =>
      _ClipSentenceMatchesSectionState();
}

enum _SearchState { idle, loading, done, unavailable, failed }

class _ClipSentenceMatchesSectionState
    extends State<ClipSentenceMatchesSection> {
  _SearchState state = _SearchState.idle;
  List<ClipSentenceMatch> matches = const [];

  /// 앱의 클립 DB로 찾는다. 클립 DB가 없는 곳(일부 테스트)에서는 '준비 중'.
  ClipSentenceFinder get _finder {
    final given = widget.finder;
    if (given != null) return given;
    final db = context.read<AppDatabase?>();
    final clips = context.read<ClipProvider?>();
    if (db == null || clips == null) {
      return const ClipSentenceFinder(UnavailableClipSegmentSource());
    }
    return ClipSentenceFinder(
        DbClipSegmentSource(db, clips.service.getAllVisibleClips));
  }

  Future<void> search() async {
    final finder = _finder;
    setState(() => state = _SearchState.loading);
    try {
      final found = await finder.find(widget.sentence);
      if (!mounted) return;
      setState(() {
        matches = found;
        state = _SearchState.done;
      });
    } on ClipSearchUnavailable {
      if (mounted) setState(() => state = _SearchState.unavailable);
    } catch (_) {
      if (mounted) setState(() => state = _SearchState.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final muted =
        context.texts.labelMedium.copyWith(color: colors.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.smart_display_rounded, size: 18),
          const SizedBox(width: 8),
          const Expanded(
              child: Text('이 문장이 나오는 클립',
                  style: TextStyle(fontWeight: FontWeight.w800))),
          TextButton(
            key: const ValueKey('search-clips'),
            onPressed: state == _SearchState.loading ? null : search,
            child: state == _SearchState.loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(state == _SearchState.idle ? '클립에서 찾기' : '다시 찾기'),
          ),
        ]),
        switch (state) {
          _SearchState.unavailable => Text(
              '클립 검색은 아직 준비 중이에요.',
              key: const ValueKey('clip-search-message'),
              style: muted,
            ),
          _SearchState.failed => Text(
              '클립을 찾지 못했어요. 다시 시도해주세요.',
              key: const ValueKey('clip-search-message'),
              style: muted,
            ),
          _SearchState.done when matches.isEmpty => Text(
              '이 문장이 들어간 클립이 없어요.',
              key: const ValueKey('clip-search-message'),
              style: muted,
            ),
          _SearchState.done => Column(children: [
              for (final match in matches) _ClipMatchTile(match: match),
            ]),
          _ => const SizedBox.shrink(),
        },
      ],
    );
  }
}

class _ClipMatchTile extends StatelessWidget {
  const _ClipMatchTile({required this.match});
  final ClipSentenceMatch match;

  String get time {
    final seconds = match.segment.startMs ~/ 1000;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      key: ValueKey('clip-match-${match.segment.clipId}-${match.segment.startMs}'),
      contentPadding: EdgeInsets.zero,
      dense: true,
      trailing: Icon(Icons.play_circle_outline_rounded, color: colors.primary),
      // 누르면 이 상세 창을 닫고 그 클립 플레이어를 연다. 창을 연 채로 열면
      // 플레이어가 창 아래에 깔린다.
      onTap: () {
        final router = GoRouter.of(context);
        Navigator.of(context).pop();
        router.push('${AppRoutes.clipsPath}/${AppRoutes.clipsPlayPath}'
            '?clipId=${match.segment.clipId}');
      },
      title: Text(match.segment.original,
          maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text('${match.segment.clipTitle} · $time · ${match.kind.label}',
          style:
              context.texts.bodySmall.copyWith(color: colors.onSurfaceVariant)),
    );
  }
}
