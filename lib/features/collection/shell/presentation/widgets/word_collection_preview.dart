import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/content/cloud_sentence_assist.dart';
import 'package:parrokit/core/content/my_word_store.dart';
import 'package:parrokit/core/content/sentence_assist.dart';
import 'package:parrokit/core/content/word_review_store.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/widgets/app_empty_state.dart';
import 'package:parrokit/core/shared/widgets/learning_language_picker.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/features/collection/library/presentation/widgets/swipe_action_tile.dart';
import 'package:parrokit/features/collection/shared/collection_tokens.dart';
import 'package:parrokit/core/shared/widgets/app_bottom_sheet.dart';

/// 보관함 > 단어 탭. 문장 탭과 같은 구조로 "내 단어"를 보여준다(5차 6번).
///
/// 예전에는 예시 데이터로 그린 미리보기였다. 이제 [MyWordStore]에 저장한 단어를
/// 언어·칩으로 거르고, "오늘 다시 볼 단어"를 [WordReviewStore]로 계산한다.
/// 둘러보기(다른 사람 단어)는 만들지 않는다(사용자 결정).
class WordCollectionPreview extends StatefulWidget {
  const WordCollectionPreview({super.key});

  @override
  State<WordCollectionPreview> createState() => _WordCollectionPreviewState();
}

class _WordCollectionPreviewState extends State<WordCollectionPreview> {
  static const categories = ['전체', '문장에서', '직접 추가'];

  String language = '영어';
  String category = '전체';
  String accountId = 'guest';
  bool loadedOnce = false;
  List<MyWord> words = [];
  Map<String, WordReview> reviews = {};
  final _swipeKeys = <String, GlobalKey<SwipeActionTileState>>{};

  @override
  void initState() {
    super.initState();
    MyWordStore.revision.addListener(reload);
  }

  @override
  void dispose() {
    MyWordStore.revision.removeListener(reload);
    super.dispose();
  }

  Future<void> reload() async {
    final requested = accountId;
    try {
      final results = await Future.wait([
        MyWordStore.load(requested),
        WordReviewStore.loadAll(requested),
      ]);
      if (!mounted || requested != accountId) return;
      setState(() {
        words = results[0] as List<MyWord>;
        reviews = results[1] as Map<String, WordReview>;
      });
    } catch (_) {/* 읽지 못하면 빈 목록으로 둔다 */}
  }

  List<MyWord> get languageWords =>
      words.where((w) => w.language == language).toList();

  List<MyWord> get visibleWords {
    final list = switch (category) {
      '문장에서' => languageWords.where((w) => w.sourceSentenceId.isNotEmpty),
      '직접 추가' => languageWords.where((w) => w.sourceSentenceId.isEmpty),
      _ => languageWords,
    };
    // 최근에 넣은 단어가 위로.
    return list.toList().reversed.toList();
  }

  Future<void> addWord() async {
    final result = await showAppSheet<WordAddResult>(
      context: context,
      builder: (_) => AddWordSheet(accountId: accountId, language: language),
    );
    if (!mounted || result == null) return;
    showWordAddResult(context, result);
  }

  Future<void> startReview(List<MyWord> due) async {
    await showAppSheet<void>(
      context: context,
      builder: (_) => WordReviewSheet(accountId: accountId, words: due),
    );
  }

  Future<void> openDetails(MyWord word) async {
    await showAppSheet<void>(
      context: context,
      builder: (_) => _WordDetailSheet(
        word: word,
        review: reviews[word.id],
        accountId: accountId,
        messenger: ScaffoldMessenger.maybeOf(context),
        onDelete: () => remove(word),
      ),
    );
  }

  Future<void> remove(MyWord word) async {
    await MyWordStore.remove(accountId, word.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("'${word.word}' 단어를 지웠어요.")));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final currentAccountId =
        context.watch<UserProvider?>()?.currentUser?.id ?? 'guest';
    if (!loadedOnce || currentAccountId != accountId) {
      loadedOnce = true;
      accountId = currentAccountId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) reload();
      });
    }
    final due =
        WordReviewStore.dueWords(languageWords, reviews, DateTime.now());
    final visible = visibleWords;

    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        key: const PageStorageKey('word-collection'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 140),
        children: [
          // 문장 탭처럼 학습 언어는 칩 줄 맨 앞에 둔다.
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Center(
                    child: LearningLanguagePicker(
                      compact: true,
                      value: language,
                      onChanged: (value) => setState(() => language = value),
                    ),
                  );
                }
                final item = categories[index - 1];
                return Center(
                  child: ChoiceChip(
                    label: Text(item),
                    selected: category == item,
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() => category = item),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          if (due.isNotEmpty) ...[
            _ReviewSummary(count: due.length, onStart: () => startReview(due)),
            const SizedBox(height: 22),
          ],
          Row(children: [
            Text('내 단어', style: context.texts.titleLarge),
            const SizedBox(width: 6),
            Text('${languageWords.length}',
                style: context.texts.titleMedium
                    .copyWith(color: colors.onSurfaceVariant)),
            const Spacer(),
            IconButton(
              key: const ValueKey('add-word'),
              tooltip: '단어 추가',
              onPressed: addWord,
              icon: const Icon(Icons.add_rounded),
            ),
          ]),
          const SizedBox(height: 4),
          if (languageWords.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: AppEmptyState(
                icon: Icons.spellcheck_rounded,
                title: '아직 모은 단어가 없어요',
                description: '문장 상세에서 단어를 골라 저장하거나 직접 추가해요',
                actionLabel: '단어 추가',
                onAction: addWord,
                compact: true,
              ),
            )
          else if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('이 조건에 맞는 단어가 없어요.',
                  textAlign: TextAlign.center,
                  style: context.texts.bodySmall
                      .copyWith(color: colors.onSurfaceVariant)),
            )
          else
            for (final word in visible)
              _WordTile(
                key: ValueKey('word-${word.id}'),
                word: word,
                review: reviews[word.id],
                swipeKey: _swipeKeys.putIfAbsent(
                    word.id, GlobalKey<SwipeActionTileState>.new),
                onOpen: () => openDetails(word),
                onDelete: () => remove(word),
              ),
        ],
      ),
    );
  }
}

/// 저장 결과를 한 줄로 알린다. 문장 상세에서 단어를 저장할 때도 쓴다.
void showWordAddResult(BuildContext context, WordAddResult result) {
  final text = switch (result) {
    WordAddResult.added => '단어를 저장했어요.',
    WordAddResult.duplicate => '이미 저장한 단어예요.',
    WordAddResult.savedOnDevice => '서버에 저장하지 못해 이 기기에 저장했어요.',
  };
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class _ReviewSummary extends StatelessWidget {
  const _ReviewSummary({required this.count, required this.onStart});

  final int count;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      decoration: BoxDecoration(
        color: context.collectionTokens.cream,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(children: [
        Icon(Icons.bolt_rounded, color: context.collectionTokens.creamInk),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('오늘 다시 볼 단어 $count개', style: context.texts.titleMedium),
            const SizedBox(height: 2),
            // 복습 창에는 말하기가 없다. 실제로 하는 일(뜻 떠올리고 알았는지 고르기)대로(5차).
            Text('뜻을 떠올려 보고 알았는지 골라요',
                style: context.texts.bodySmall
                    .copyWith(color: colors.onSurfaceVariant)),
          ]),
        ),
        FilledButton(
          key: const ValueKey('start-word-review'),
          onPressed: onStart,
          child: const Text('시작'),
        ),
      ]),
    );
  }
}

/// 내 단어 한 줄. 테두리 없는 줄 + 밀어서 삭제(문장 탭과 같은 모양).
class _WordTile extends StatelessWidget {
  const _WordTile({
    super.key,
    required this.word,
    required this.review,
    required this.swipeKey,
    required this.onOpen,
    required this.onDelete,
  });

  final MyWord word;
  final WordReview? review;
  final GlobalKey<SwipeActionTileState> swipeKey;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final step = (review?.step ?? 0).clamp(0, WordReviewStore.intervals.length);
    final body = Material(
      color: colors.surface,
      child: InkWell(
        onTap: () {
          if (swipeKey.currentState?.isOpen ?? false) {
            swipeKey.currentState?.close();
            return;
          }
          onOpen();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(word.word,
                        style: context.texts.titleMedium
                            .copyWith(fontWeight: FontWeight.w800)),
                    if (word.meaning.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(word.meaning,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.texts.bodySmall
                              .copyWith(color: colors.onSurfaceVariant)),
                    ],
                  ]),
            ),
            // 복습 단계: 알아요를 누를 때마다 점이 하나씩 찬다.
            Semantics(
              label: '복습 $step단계',
              child: Row(children: [
                for (var i = 0; i < WordReviewStore.intervals.length; i++)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(left: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < step
                          ? colors.primary
                          : colors.outlineVariant.withValues(alpha: 0.6),
                    ),
                  ),
              ]),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
          ]),
        ),
      ),
    );
    return SwipeActionTile(
      key: swipeKey,
      actionWidth: 84,
      actions: [
        Expanded(
          child: Material(
            color: colors.error,
            child: InkWell(
              onTap: () {
                swipeKey.currentState?.close();
                onDelete();
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_outline_rounded,
                      color: colors.onError, size: 20),
                  const SizedBox(height: 2),
                  Text('삭제',
                      style: context.texts.labelSmall
                          .copyWith(color: colors.onError)),
                ],
              ),
            ),
          ),
        ),
      ],
      child: body,
    );
  }
}

/// 단어 상세 창을 띄운다. 보관함 검색처럼 단어 탭 밖에서 열 때 쓴다(5차).
/// 지우면 [MyWordStore.revision]이 올라가 단어 탭도 다시 읽는다.
Future<void> showWordDetails(
  BuildContext context, {
  required MyWord word,
  required String accountId,
}) async {
  final reviews = await WordReviewStore.loadAll(accountId);
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  await showAppSheet<void>(
    context: context,
    builder: (_) => _WordDetailSheet(
      word: word,
      review: reviews[word.id],
      accountId: accountId,
      messenger: messenger,
      onDelete: () async {
        await MyWordStore.remove(accountId, word.id);
        messenger
            ?.showSnackBar(SnackBar(content: Text("'${word.word}' 단어를 지웠어요.")));
      },
    ),
  );
}

/// 단어 상세의 다음 복습 안내. 기한은 그날 0시로 저장되므로(dueDayAfter) 달력
/// 날짜로 센다(5차). 예전엔 지금 시각과의 차이(inDays)로 세어 밤 11시에 '내일 0시'
/// 기한이 '오늘 복습할 단어'로, 이틀 뒤가 '1일 뒤'로 나왔다.
@visibleForTesting
String wordDueLabel(DateTime? due, DateTime now) {
  if (due == null) return '아직 복습 전';
  final days = DateTime(due.year, due.month, due.day)
      .difference(DateTime(now.year, now.month, now.day))
      .inDays;
  if (days <= 0) return '오늘 복습할 단어';
  if (days == 1) return '내일 복습';
  return '$days일 뒤 복습';
}

/// 뜻을 적는 작은 창. 입력칸 컨트롤러를 이 창이 가지고 있다가 닫힐 때
/// 버린다. 부르는 쪽에서 showDialog가 끝나자마자 버렸더니, 닫히는 동안
/// 그려지는 중에 "used after being disposed"가 났다(5차).
class _MeaningDialog extends StatefulWidget {
  const _MeaningDialog({required this.word, required this.meaning});

  final String word;
  final String meaning;

  @override
  State<_MeaningDialog> createState() => _MeaningDialogState();
}

class _MeaningDialogState extends State<_MeaningDialog> {
  late final _controller = TextEditingController(text: widget.meaning);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.meaning.isEmpty ? '뜻 적기' : '뜻 고치기'),
        content: TextField(
          key: const ValueKey('word-meaning-input'),
          controller: _controller,
          autofocus: true,
          maxLength: meaningMaxLength,
          decoration: InputDecoration(hintText: widget.word),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const ValueKey('word-meaning-save'),
            onPressed: () => Navigator.pop(context, _controller.text),
            child: const Text('저장'),
          ),
        ],
      );
}

class _WordDetailSheet extends StatefulWidget {
  const _WordDetailSheet({
    required this.word,
    required this.review,
    required this.accountId,
    required this.messenger,
    required this.onDelete,
  });

  final MyWord word;
  final WordReview? review;
  final String accountId;
  final ScaffoldMessengerState? messenger;
  final VoidCallback onDelete;

  @override
  State<_WordDetailSheet> createState() => _WordDetailSheetState();
}

class _WordDetailSheetState extends State<_WordDetailSheet> {
  late String meaning = widget.word.meaning;

  /// 뜻을 적거나 고친다. 전에는 뜻이 비어 있으면 지우고 다시 넣는 수밖에
  /// 없었다(문장에서 단어만 고르면 뜻이 비어 있다, 5차).
  Future<void> _editMeaning() async {
    final next = await showDialog<String>(
      context: context,
      builder: (_) => _MeaningDialog(word: widget.word.word, meaning: meaning),
    );
    if (!mounted || next == null) return;

    final saved = await MyWordStore.setMeaning(
        widget.accountId, widget.word.id, next);
    if (!mounted) return;
    if (!saved) {
      widget.messenger?.showSnackBar(
          const SnackBar(content: Text('뜻을 저장하지 못했어요. 다시 시도해주세요.')));
      return;
    }
    setState(() => meaning = next.trim());
  }

  @override
  Widget build(BuildContext context) {
    final word = widget.word;
    final review = widget.review;
    final colors = Theme.of(context).colorScheme;
    final muted =
        context.texts.bodySmall.copyWith(color: colors.onSurfaceVariant);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(word.word, style: context.texts.headlineSmall),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                      meaning.isEmpty ? '뜻을 아직 적지 않았어요' : meaning,
                      key: const ValueKey('word-detail-meaning'),
                      style: context.texts.bodyLarge.copyWith(
                          color: meaning.isEmpty
                              ? colors.onSurfaceVariant
                              : null)),
                ),
                TextButton(
                  key: const ValueKey('edit-word-meaning'),
                  onPressed: _editMeaning,
                  child: Text(meaning.isEmpty ? '뜻 적기' : '뜻 고치기'),
                ),
              ],
            ),
            // 예문은 여러 개일 수 있다(5차).
            for (final (index, example) in word.examples.indexed) ...[
              SizedBox(height: index == 0 ? 16 : 8),
              Container(
                key: ValueKey('word-detail-example-$index'),
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(example.text,
                          style: context.texts.bodyMedium
                              .copyWith(fontWeight: FontWeight.w700)),
                      if (example.translation.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(example.translation, style: muted),
                      ],
                    ]),
              ),
            ],
            const SizedBox(height: 12),
            Text(
                [
                  if (word.sourceSentenceId.isNotEmpty) '문장에서 저장',
                  wordDueLabel(review?.dueAt, DateTime.now()),
                ].join(' · '),
                style: muted),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const ValueKey('delete-word'),
                onPressed: () {
                  Navigator.pop(context);
                  widget.onDelete();
                },
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('단어 지우기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 단어 직접 추가. 단어만 넣어도 저장된다(뜻·예문은 선택).
class AddWordSheet extends StatefulWidget {
  const AddWordSheet({
    super.key,
    required this.accountId,
    required this.language,
    this.initialWord = '',
    this.example = '',
    this.exampleTranslation = '',
    this.sourceSentenceId = '',
    this.assist,
  });

  final String accountId;
  final String language;
  final String initialWord;

  /// 뜻 채우기. 문장 추가의 '뜻·발음 채우기'와 같은 서버 호출(suggestSentenceInfo)을
  /// 쓰고 하루 횟수도 함께 쓴다. 안 주면 서버를 부르는 기본값.
  final SentenceAssist? assist;

  /// 문장 상세에서 열면 그 문장이 예문으로 미리 들어간다.
  final String example;
  final String exampleTranslation;
  final String sourceSentenceId;

  @override
  State<AddWordSheet> createState() => _AddWordSheetState();
}

class _AddWordSheetState extends State<AddWordSheet> {
  late final _word = TextEditingController(text: widget.initialWord);
  final _meaning = TextEditingController();
  /// 예문 입력칸. 같은 단어를 여러 문장에서 만나므로 여러 개를 적을 수 있다(5차).
  late final List<TextEditingController> _examples = [
    TextEditingController(text: widget.example)
  ];
  late final SentenceAssist _assist = widget.assist ?? CloudSentenceAssist();
  bool saving = false;
  bool filling = false;

  /// 단어의 뜻을 서버에 물어 채운다. 이미 적은 뜻은 덮지 않는다.
  Future<void> fillMeaning() async {
    final word = _word.text.trim();
    if (word.isEmpty || filling) return;
    setState(() => filling = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final suggestion =
          await _assist.suggest(language: widget.language, text: word);
      final meaning = suggestion.translation?.trim() ?? '';
      if (!mounted) return;
      if (meaning.isEmpty) {
        messenger.showSnackBar(
            const SnackBar(content: Text('뜻을 찾지 못했어요. 직접 적어 주세요.')));
      } else if (_meaning.text.trim().isEmpty) {
        _meaning.text = meaning;
      }
    } on SentenceAssistQuotaExceeded {
      messenger.showSnackBar(
          const SnackBar(content: Text('오늘 자동 채우기를 모두 썼어요. 내일 다시 쓸 수 있어요.')));
    } on SentenceAssistUnavailable catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.reason)));
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('뜻을 채우지 못했어요. 직접 적어 주세요.')));
    } finally {
      if (mounted) setState(() => filling = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _word.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _word.dispose();
    _meaning.dispose();
    for (final c in _examples) {
      c.dispose();
    }
    super.dispose();
  }

  void addExampleField() {
    if (_examples.length >= examplesMaxCount) return;
    setState(() => _examples.add(TextEditingController()));
  }

  void removeExampleField(int index) {
    if (_examples.length <= 1) return;
    setState(() => _examples.removeAt(index).dispose());
  }

  Future<void> save() async {
    if (saving || _word.text.trim().isEmpty) return;
    setState(() => saving = true);
    final result = await MyWordStore.add(
      widget.accountId,
      language: widget.language,
      word: _word.text,
      meaning: _meaning.text,
      examples: [
        for (final c in _examples)
          WordExample(
            text: c.text,
            // 미리 채워 준 문장은 그 문장의 뜻과 id를 그대로 붙인다.
            translation: c.text.trim() == widget.example.trim()
                ? widget.exampleTranslation
                : '',
            sourceSentenceId: c.text.trim() == widget.example.trim()
                ? widget.sourceSentenceId
                : '',
          ),
      ],
    );
    if (!mounted) return;
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('단어 추가', style: context.texts.titleLarge),
              const SizedBox(height: 4),
              Text('${widget.language} · 단어만 넣어도 저장돼요',
                  style: context.texts.bodySmall.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('word-input'),
                controller: _word,
                autofocus: widget.initialWord.isEmpty,
                maxLength: 80,
                decoration: const InputDecoration(
                    labelText: '단어나 표현', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('word-meaning'),
                controller: _meaning,
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: '뜻 (선택)',
                  border: const OutlineInputBorder(),
                  // 단어를 적으면 뜻을 자동으로 채울 수 있다.
                  suffixIcon: filling
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : IconButton(
                          key: const ValueKey('fill-word-meaning'),
                          tooltip: '뜻 채우기',
                          onPressed:
                              _word.text.trim().isEmpty ? null : fillMeaning,
                          icon: const Icon(Icons.auto_awesome_rounded),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              for (final (index, controller) in _examples.indexed) ...[
                if (index > 0) const SizedBox(height: 8),
                TextField(
                  key: ValueKey('word-example-$index'),
                  controller: controller,
                  maxLength: 300,
                  maxLines: 2,
                  minLines: 1,
                  decoration: InputDecoration(
                    labelText: _examples.length == 1
                        ? '예문 (선택)'
                        : '예문 ${index + 1}',
                    border: const OutlineInputBorder(),
                    suffixIcon: _examples.length == 1
                        ? null
                        : IconButton(
                            key: ValueKey('remove-word-example-$index'),
                            tooltip: '이 예문 지우기',
                            onPressed: () => removeExampleField(index),
                            icon: const Icon(Icons.close_rounded, size: 20),
                          ),
                  ),
                ),
              ],
              if (_examples.length < examplesMaxCount)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const ValueKey('add-word-example'),
                    onPressed: addExampleField,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('예문 더 넣기'),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('save-word'),
                  onPressed: _word.text.trim().isEmpty || saving ? null : save,
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48)),
                  child: const Text('저장'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 오늘 복습. 단어를 보고 뜻을 떠올린 뒤 "뜻 보기", 그다음 "다시"/"알아요".
class WordReviewSheet extends StatefulWidget {
  const WordReviewSheet({
    super.key,
    required this.accountId,
    required this.words,
  });

  final String accountId;
  final List<MyWord> words;

  @override
  State<WordReviewSheet> createState() => _WordReviewSheetState();
}

class _WordReviewSheetState extends State<WordReviewSheet> {
  /// 이번 바퀴에서 볼 단어. '다시'를 고른 단어만 모아 한 바퀴 더 돌 수 있다.
  late List<MyWord> queue = widget.words;
  int index = 0;
  bool revealed = false;
  int knownCount = 0;

  /// 이번 바퀴에서 '다시'를 고른 단어.
  final List<MyWord> again = [];

  /// 몇 바퀴째인지(0이면 오늘 처음 도는 중). '다시' 고른 것만 다시 돌 때
  /// 화면이 그대로여서 처음부터 다시 하는 것처럼 보였다(5차).
  int round = 0;

  Future<void> answer(bool known) async {
    final word = queue[index];
    unawaited(WordReviewStore.record(widget.accountId, word.id, known: known));
    setState(() {
      if (known) {
        knownCount++;
      } else {
        again.add(word);
      }
      index++;
      revealed = false;
    });
  }

  /// '다시'로 고른 단어만 다시 돈다. '다시'는 기한을 오늘로 두므로(record)
  /// 전에는 창을 닫고 '시작'을 다시 눌러야 그 단어를 또 볼 수 있었다(5차).
  void reviewAgain() {
    setState(() {
      queue = List.of(again);
      again.clear();
      index = 0;
      knownCount = 0;
      revealed = false;
      round++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final done = index >= queue.length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Text(round == 0 ? '오늘 복습' : "'다시' 고른 단어",
                  key: const ValueKey('review-title'),
                  style: context.texts.titleLarge),
              const Spacer(),
              Text(
                  done
                      ? '${queue.length} / ${queue.length}'
                      : '${index + 1} / ${queue.length}',
                  style: context.texts.bodySmall
                      .copyWith(color: colors.onSurfaceVariant)),
            ]),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: queue.isEmpty
                  ? 1
                  : index.clamp(0, queue.length) / queue.length,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            const SizedBox(height: 24),
            if (done) ...[
              Icon(Icons.check_circle_rounded, size: 48, color: colors.primary),
              const SizedBox(height: 12),
              Text(round == 0 ? '오늘 복습을 마쳤어요' : '다시 본 단어까지 끝냈어요',
                  key: const ValueKey('review-done-title'),
                  style: context.texts.titleMedium),
              const SizedBox(height: 4),
              Text('알아요 $knownCount개 · 다시 ${queue.length - knownCount}개',
                  style: context.texts.bodySmall
                      .copyWith(color: colors.onSurfaceVariant)),
              const SizedBox(height: 20),
              if (again.isNotEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey('review-again-round'),
                    onPressed: reviewAgain,
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48)),
                    child: Text("'다시' 고른 ${again.length}개 한 번 더"),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                child: again.isEmpty
                    ? FilledButton(
                        key: const ValueKey('finish-word-review'),
                        onPressed: () => Navigator.pop(context),
                        style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48)),
                        child: const Text('닫기'),
                      )
                    : OutlinedButton(
                        key: const ValueKey('finish-word-review'),
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48)),
                        child: const Text('닫기'),
                      ),
              ),
            ] else ...[
              Text(queue[index].word,
                  key: const ValueKey('review-word'),
                  textAlign: TextAlign.center,
                  style: context.texts.headlineMedium),
              const SizedBox(height: 16),
              SizedBox(
                height: 96,
                child: revealed
                    ? Column(children: [
                        Text(
                            queue[index].meaning.isEmpty
                                ? '뜻을 아직 적지 않았어요'
                                : queue[index].meaning,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.texts.bodyLarge),
                        if (queue[index].example.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(queue[index].example,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.texts.bodySmall
                                  .copyWith(color: colors.onSurfaceVariant)),
                        ],
                      ])
                    : Center(
                        child: Text('뜻을 떠올려 보세요',
                            style: context.texts.bodyMedium
                                .copyWith(color: colors.onSurfaceVariant)),
                      ),
              ),
              const SizedBox(height: 16),
              // 뜻을 본 뒤에만 '다시/알아요'를 고른다(5차). 예전엔 처음부터 두 버튼이
              // 있어 뜻을 안 보고도, 또는 잘못 연달아 눌러 기록이 남았다.
              if (!revealed)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    key: const ValueKey('reveal-word'),
                    onPressed: () => setState(() => revealed = true),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48)),
                    child: const Text('뜻 보기'),
                  ),
                )
              else
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('review-again'),
                      onPressed: () => answer(false),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48)),
                      child: const Text('다시'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('review-known'),
                      onPressed: () => answer(true),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48)),
                      child: const Text('알아요'),
                    ),
                  ),
                ]),
            ],
          ],
        ),
      ),
    );
  }
}
