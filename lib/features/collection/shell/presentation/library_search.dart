import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:parrokit/core/content/clip_sentence_match.dart';
import 'package:parrokit/core/content/db_clip_segment_source.dart';
import 'package:parrokit/core/content/default_conversation_sentences.dart';
import 'package:parrokit/core/content/my_sentence_store.dart';
import 'package:parrokit/core/content/my_word_store.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/state/provider/clip_provider.dart';
import 'package:parrokit/data/local/app_database.dart';

import 'widgets/sentence_collection_preview.dart';
import 'widgets/word_collection_preview.dart';

/// 보관함 검색이 찾는 대상. 화면을 열 때 한 번 읽어 두고, 글자를 칠 때마다
/// 메모리에서 거른다.
class LibrarySearchData {
  const LibrarySearchData({
    this.sentences = const [],
    this.words = const [],
    this.clips = const [],
    this.segments = const [],
  });

  final List<DefaultConversationSentence> sentences;
  final List<MyWord> words;

  /// (클립 id, 제목)
  final List<(int, String)> clips;
  final List<ClipSegmentRef> segments;
}

/// 찾은 클립 하나. 제목이 맞으면 [line]은 비어 있고, 자막이 맞으면 그 줄.
class LibraryClipHit {
  const LibraryClipHit({required this.clipId, required this.title, this.line});

  final int clipId;
  final String title;
  final String? line;
}

class LibrarySearchResults {
  const LibrarySearchResults({
    this.sentences = const [],
    this.words = const [],
    this.clips = const [],
    this.moreSentences = false,
    this.moreWords = false,
    this.moreClips = false,
  });

  final List<DefaultConversationSentence> sentences;
  final List<MyWord> words;
  final List<LibraryClipHit> clips;

  /// [limit]보다 많이 맞아서 잘랐는지. 화면에 '20+'로 보인다.
  final bool moreSentences;
  final bool moreWords;
  final bool moreClips;

  bool get isEmpty => sentences.isEmpty && words.isEmpty && clips.isEmpty;
}

/// 대소문자와 띄어쓰기를 무시하고 비교한다('안녕 하세요'로 '안녕하세요'를 찾는다).
String _norm(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'\s+'), '');

/// [query]가 들어 있는 내 문장(문장·뜻·발음), 내 단어(단어·뜻·예문),
/// 클립(제목·자막 원문·해석)을 종류마다 [limit]개까지 찾는다.
LibrarySearchResults searchLibrary(
  String query,
  LibrarySearchData data, {
  int limit = 20,
}) {
  final q = _norm(query);
  if (q.isEmpty) return const LibrarySearchResults();
  bool has(String value) => _norm(value).contains(q);

  final sentences = data.sentences
      .where((s) => has(s.text) || has(s.translation) || has(s.pronunciation))
      .take(limit + 1)
      .toList();
  final words = data.words
      .where((w) =>
          has(w.word) ||
          has(w.meaning) ||
          // 예문은 여러 개일 수 있다(5차). 첫 예문만 보면 뒤 예문으로 못 찾는다.
          w.examples
              .any((e) => has(e.text) || has(e.translation)))
      .take(limit + 1)
      .toList();

  final clips = <LibraryClipHit>[];
  final seen = <int>{};
  for (final (id, title) in data.clips) {
    if (clips.length > limit) break;
    if (has(title)) {
      clips.add(LibraryClipHit(clipId: id, title: title));
      seen.add(id);
    }
  }
  for (final s in data.segments) {
    if (clips.length > limit) break;
    if (seen.contains(s.clipId)) continue;
    if (has(s.original) || has(s.translation)) {
      clips.add(LibraryClipHit(
          clipId: s.clipId, title: s.clipTitle, line: s.original));
      seen.add(s.clipId);
    }
  }
  List<T> cut<T>(List<T> list) =>
      list.length > limit ? list.sublist(0, limit) : list;
  return LibrarySearchResults(
    sentences: cut(sentences),
    words: cut(words),
    clips: cut(clips),
    moreSentences: sentences.length > limit,
    moreWords: words.length > limit,
    moreClips: clips.length > limit,
  );
}

/// 보관함 머리의 검색 창. 예전에는 입력칸만 있고 아무것도 찾지 않았다(5차).
class LibrarySearchSheet extends StatefulWidget {
  const LibrarySearchSheet({
    super.key,
    required this.accountId,
    required this.onOpenClip,
    this.load,
  });

  final String accountId;

  /// 검색 창을 닫은 뒤 클립 플레이어를 연다.
  final void Function(int clipId) onOpenClip;

  /// 테스트에서 데이터를 넣을 때 쓴다. 없으면 기기·계정 저장소와 클립 DB에서 읽는다.
  final Future<LibrarySearchData> Function()? load;

  @override
  State<LibrarySearchSheet> createState() => _LibrarySearchSheetState();
}

class _LibrarySearchSheetState extends State<LibrarySearchSheet> {
  final _controller = TextEditingController();
  LibrarySearchData? _data;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<LibrarySearchData> _defaultLoad() async {
    final db = context.read<AppDatabase?>();
    final clipProvider = context.read<ClipProvider?>();
    final accountId = widget.accountId;
    final results = await Future.wait([
      MySentenceStore.load(accountId).catchError((_) => <DefaultConversationSentence>[]),
      MyWordStore.load(accountId).catchError((_) => <MyWord>[]),
    ]);
    var clips = const <(int, String)>[];
    var segments = const <ClipSegmentRef>[];
    if (db != null && clipProvider != null) {
      final visible = await clipProvider.service.getAllVisibleClips();
      clips = [for (final c in visible) (c.id, c.title)];
      segments = await DbClipSegmentSource(db, () async => visible).loadSegments();
    }
    return LibrarySearchData(
      sentences: results[0] as List<DefaultConversationSentence>,
      words: results[1] as List<MyWord>,
      clips: clips,
      segments: segments,
    );
  }

  Future<void> _reload() async {
    try {
      final data = await (widget.load ?? _defaultLoad)();
      if (!mounted) return;
      setState(() {
        _data = data;
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _openSentence(DefaultConversationSentence sentence) async {
    await showSentenceDetails(context,
        sentence: sentence, accountId: widget.accountId);
    // 상세에서 지웠을 수 있으니 다시 읽는다.
    if (mounted) await _reload();
  }

  Future<void> _openWord(MyWord word) async {
    await showWordDetails(context, word: word, accountId: widget.accountId);
    if (mounted) await _reload();
  }

  void _openClip(int clipId) {
    Navigator.pop(context);
    widget.onOpenClip(clipId);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final muted =
        context.texts.bodyMedium.copyWith(color: colors.onSurfaceVariant);
    final query = _controller.text;
    final data = _data;
    final results = data == null
        ? const LibrarySearchResults()
        : searchLibrary(query, data);

    Widget body;
    if (_failed) {
      body = Text('불러오지 못했어요. 창을 닫고 다시 열어 주세요.', style: muted);
    } else if (data == null) {
      body = const Center(
          child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator()));
    } else if (query.trim().isEmpty) {
      body = Text('내 문장·단어와 클립 제목·자막에서 찾아요.', style: muted);
    } else if (results.isEmpty) {
      body = Text("'${query.trim()}' 검색 결과가 없어요.",
          key: const ValueKey('library-search-empty'), style: muted);
    } else {
      body = ListView(
        key: const ValueKey('library-search-results'),
        padding: EdgeInsets.zero,
        children: [
          if (results.sentences.isNotEmpty) ...[
            _SectionLabel('문장 ${_count(results.sentences.length, results.moreSentences)}'),
            for (final s in results.sentences)
              _ResultTile(
                icon: Icons.format_quote_rounded,
                title: s.text,
                subtitle: s.translation,
                onTap: () => _openSentence(s),
              ),
          ],
          if (results.words.isNotEmpty) ...[
            _SectionLabel('단어 ${_count(results.words.length, results.moreWords)}'),
            for (final w in results.words)
              _ResultTile(
                icon: Icons.spellcheck_rounded,
                title: w.word,
                subtitle: w.meaning,
                onTap: () => _openWord(w),
              ),
          ],
          if (results.clips.isNotEmpty) ...[
            _SectionLabel('클립 ${_count(results.clips.length, results.moreClips)}'),
            for (final c in results.clips)
              _ResultTile(
                icon: Icons.play_circle_outline_rounded,
                title: c.title,
                subtitle: c.line ?? '',
                onTap: () => _openClip(c.clipId),
              ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const ValueKey('library-search-field'),
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: '문장, 단어, 클립 검색',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: '지우기',
                    onPressed: () => setState(_controller.clear),
                    icon: const Icon(Icons.close_rounded),
                  ),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: body),
      ],
    );
  }
}

String _count(int shown, bool more) => more ? '$shown+' : '$shown';

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(text,
            style: context.texts.labelLarge.copyWith(
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
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
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: subtitle.isEmpty
            ? null
            : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        onTap: onTap,
      );
}
