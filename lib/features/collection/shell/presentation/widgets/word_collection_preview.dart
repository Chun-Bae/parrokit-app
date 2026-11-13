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
    final result = await showModalBottomSheet<WordAddResult>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => AddWordSheet(accountId: accountId, language: language),
    );
    if (!mounted || result == null) return;
    showWordAddResult(context, result);
  }

  Future<void> startReview(List<MyWord> due) async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => WordReviewSheet(accountId: accountId, words: due),
    );
  }

  Future<void> openDetails(MyWord word) async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (_) => _WordDetailSheet(
        word: word,
        review: reviews[word.id],
        onDelete: () => remove(word),
      ),
    );
  }

  Future<void> remove(MyWord word) async {
    await MyWordStore.remove(accountId, word.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("'${word.word}' 단어를 지웠어요.")));
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
    final due = WordReviewStore.dueWords(languageWords, reviews, DateTime.now());
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
            _ReviewSummary(
                count: due.length, onStart: () => startReview(due)),
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('오늘 다시 볼 단어 $count개', style: context.texts.titleMedium),
            const SizedBox(height: 2),
            Text('뜻을 떠올리고 예문을 소리 내어 말해요',
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
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    builder: (_) => _WordDetailSheet(
      word: word,
      review: reviews[word.id],
      onDelete: () async {
        await MyWordStore.remove(accountId, word.id);
        messenger?.showSnackBar(
            SnackBar(content: Text("'${word.word}' 단어를 지웠어요.")));
      },
    ),
  );
}

class _WordDetailSheet extends StatelessWidget {
  const _WordDetailSheet({
    required this.word,
    required this.review,
    required this.onDelete,
  });

  final MyWord word;
  final WordReview? review;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final muted =
        context.texts.bodySmall.copyWith(color: colors.onSurfaceVariant);
    final due = review?.dueAt;
    final days = due?.difference(DateTime.now()).inDays;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(word.word, style: context.texts.headlineSmall),
            const SizedBox(height: 4),
            Text(word.meaning.isEmpty ? '뜻을 아직 적지 않았어요' : word.meaning,
                style: context.texts.bodyLarge),
            if (word.example.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(word.example,
                          style: context.texts.bodyMedium
                              .copyWith(fontWeight: FontWeight.w700)),
                      if (word.exampleTranslation.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(word.exampleTranslation, style: muted),
                      ],
                    ]),
              ),
            ],
            const SizedBox(height: 12),
            Text(
                [
                  if (word.sourceSentenceId.isNotEmpty) '문장에서 저장',
                  if (days == null)
                    '아직 복습 전'
                  else if (days <= 0)
                    '오늘 복습할 단어'
                  else
                    '$days일 뒤 복습',
                ].join(' · '),
                style: muted),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const ValueKey('delete-word'),
                onPressed: () {
                  Navigator.pop(context);
                  onDelete();
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
  late final _example = TextEditingController(text: widget.example);
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
      messenger.showSnackBar(const SnackBar(
          content: Text('오늘 자동 채우기를 모두 썼어요. 내일 다시 쓸 수 있어요.')));
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
    _example.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving || _word.text.trim().isEmpty) return;
    setState(() => saving = true);
    final result = await MyWordStore.add(
      widget.accountId,
      language: widget.language,
      word: _word.text,
      meaning: _meaning.text,
      example: _example.text,
      exampleTranslation:
          _example.text.trim() == widget.example.trim()
              ? widget.exampleTranslation
              : '',
      sourceSentenceId: widget.sourceSentenceId,
    );
    if (!mounted) return;
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom),
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
                              child:
                                  CircularProgressIndicator(strokeWidth: 2)),
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
              TextField(
                key: const ValueKey('word-example'),
                controller: _example,
                maxLength: 300,
                maxLines: 2,
                minLines: 1,
                decoration: const InputDecoration(
                    labelText: '예문 (선택)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('save-word'),
                  onPressed:
                      _word.text.trim().isEmpty || saving ? null : save,
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
  int index = 0;
  bool revealed = false;
  int knownCount = 0;

  Future<void> answer(bool known) async {
    final word = widget.words[index];
    unawaited(WordReviewStore.record(widget.accountId, word.id, known: known));
    setState(() {
      if (known) knownCount++;
      index++;
      revealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final done = index >= widget.words.length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Text('오늘 복습', style: context.texts.titleLarge),
              const Spacer(),
              Text(
                  done
                      ? '${widget.words.length} / ${widget.words.length}'
                      : '${index + 1} / ${widget.words.length}',
                  style: context.texts.bodySmall
                      .copyWith(color: colors.onSurfaceVariant)),
            ]),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: widget.words.isEmpty
                  ? 1
                  : index.clamp(0, widget.words.length) / widget.words.length,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            const SizedBox(height: 24),
            if (done) ...[
              Icon(Icons.check_circle_rounded, size: 48, color: colors.primary),
              const SizedBox(height: 12),
              Text('오늘 복습을 마쳤어요', style: context.texts.titleMedium),
              const SizedBox(height: 4),
              Text('알아요 $knownCount개 · 다시 ${widget.words.length - knownCount}개',
                  style: context.texts.bodySmall
                      .copyWith(color: colors.onSurfaceVariant)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('finish-word-review'),
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48)),
                  child: const Text('닫기'),
                ),
              ),
            ] else ...[
              Text(widget.words[index].word,
                  key: const ValueKey('review-word'),
                  textAlign: TextAlign.center,
                  style: context.texts.headlineMedium),
              const SizedBox(height: 16),
              SizedBox(
                height: 96,
                child: revealed
                    ? Column(children: [
                        Text(
                            widget.words[index].meaning.isEmpty
                                ? '뜻을 아직 적지 않았어요'
                                : widget.words[index].meaning,
                            textAlign: TextAlign.center,
                            style: context.texts.bodyLarge),
                        if (widget.words[index].example.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(widget.words[index].example,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.texts.bodySmall
                                  .copyWith(color: colors.onSurfaceVariant)),
                        ],
                      ])
                    : Center(
                        child: TextButton(
                          key: const ValueKey('reveal-word'),
                          onPressed: () => setState(() => revealed = true),
                          child: const Text('뜻 보기'),
                        ),
                      ),
              ),
              const SizedBox(height: 16),
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
