import 'package:flutter/material.dart';
import 'package:parrokit/core/content/clip_sentence_match.dart';

/// 문장 상세에서 이 문장이 나오는 클립 자막을 찾아 보여주는 구역.
class ClipSentenceMatchesSection extends StatefulWidget {
  const ClipSentenceMatchesSection({
    super.key,
    required this.sentence,
    this.finder = const ClipSentenceFinder(UnavailableClipSegmentSource()),
  });

  final String sentence;
  final ClipSentenceFinder finder;

  @override
  State<ClipSentenceMatchesSection> createState() =>
      _ClipSentenceMatchesSectionState();
}

enum _SearchState { idle, loading, done, unavailable, failed }

class _ClipSentenceMatchesSectionState
    extends State<ClipSentenceMatchesSection> {
  _SearchState state = _SearchState.idle;
  List<ClipSentenceMatch> matches = const [];

  Future<void> search() async {
    setState(() => state = _SearchState.loading);
    try {
      final found = await widget.finder.find(widget.sentence);
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
    final muted = TextStyle(color: colors.onSurfaceVariant, fontSize: 13);
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
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(match.segment.original,
          maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text('${match.segment.clipTitle} · $time · ${match.kind.label}',
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
    );
  }
}
