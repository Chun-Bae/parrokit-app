import 'package:parrokit/core/content/filtered_count_label.dart';
import 'package:parrokit/core/shared/utils/action_failed_text.dart';
import 'package:parrokit/core/content/assist_usage_text.dart';
import 'package:parrokit/core/shared/utils/optional_field_label.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/example_count_sheet.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/word_edit_sheet.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/widgets/assist_icon.dart';
import 'package:parrokit/features/settings/more/presentation/web_document_screen.dart';
import 'package:parrokit/core/content/word_search_url.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/content/cloud_sentence_assist.dart';
import 'package:parrokit/core/content/my_word_store.dart';
import 'package:parrokit/core/content/sentence_assist.dart';
import 'package:parrokit/core/content/practice_calendar.dart';
import 'package:parrokit/core/content/practice_reward.dart';
import 'package:parrokit/core/content/word_review_store.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/core/state/practice_reward_grant.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/widgets/app_empty_state.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:parrokit/features/collection/library/presentation/widgets/swipe_action_tile.dart';
import 'package:parrokit/features/collection/shared/collection_tokens.dart';
import 'package:parrokit/core/shared/widgets/app_bottom_sheet.dart';
import 'package:parrokit/core/app/config/app_config.dart';
import 'package:parrokit/core/shared/widgets/reward_celebration.dart';
import 'package:parrokit/core/shared/widgets/speak_controls.dart';
import 'package:parrokit/core/shared/widgets/tiered_header.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/sentence_filter_row.dart';
import 'collection_header_slot.dart';

/// 머리줄에 적는 개수. 거르는 중이면 '보이는 수 / 전체 수'로 적는다(5차 452).
/// 셈은 클립 탭과 함께 쓴다(5차 483).
String wordCountLabel({
  required int shown,
  required int all,
  required bool filtered,
}) =>
    filteredCountLabel(shown: shown, all: all, filtered: filtered);

/// 거른 결과가 비었을 때.
const String wordFilterEmptyText = '이 조건에 맞는 단어가 없어요.';
const String wordFilterClearLabel = '전체 보기';

/// 보관함 > 단어 탭. 문장 탭과 같은 구조로 "내 단어"를 보여준다(5차 6번).
///
/// 예전에는 예시 데이터로 그린 미리보기였다. 이제 [MyWordStore]에 저장한 단어를
/// 언어·칩으로 거르고, "오늘 다시 볼 단어"를 [WordReviewStore]로 계산한다.
/// 둘러보기(다른 사람 단어)는 만들지 않는다(사용자 결정).
class WordCollectionPreview extends StatefulWidget {
  const WordCollectionPreview({super.key, this.headerSlot});

  /// 언어·필터 줄을 보관함 머리줄로 올려 둘 자리(5차 336). 비우면 목록 안에 둔다.
  final CollectionHeaderSlot? headerSlot;

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
      builder: (_) =>
          WordReviewSheet(accountId: accountId, words: due, reviews: reviews),
    );
  }

  Future<void> openDetails(MyWord word) async {
    await showAppSheet<void>(
      context: context,
      builder: (_) => _WordDetailSheet(
        word: word,
        review: reviews[word.id],
        accountId: accountId,
        onDelete: () => remove(word),
      ),
    );
  }

  Future<void> remove(MyWord word) async {
    if (!await confirmDeleteWord(context, word.word) || !mounted) return;
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

    // 언어·필터 줄. 보관함 안에서는 머리줄로 올라간다(5차 336).
    final filterRow = SentenceFilterRow(
      language: language,
      category: category,
      categories: categories,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      onLanguageChanged: (value) => setState(() => language = value),
      onCategoryChanged: (value) => setState(() => category = value),
    );
    final slot = widget.headerSlot;
    if (slot != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        slot.put(heights: const [54], build: (_) => filterRow);
      });
    }

    return RefreshIndicator(
      onRefresh: reload,
      child: CustomScrollView(
        key: const PageStorageKey('word-collection'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (slot == null)
            SliverPersistentHeader(
              floating: true,
              delegate: TieredHeaderDelegate(tiers: [
                HeaderTier(height: 54, child: filterRow),
              ]),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 140),
            sliver: SliverList(
                delegate: SliverChildListDelegate([
              if (due.isNotEmpty) ...[
                _ReviewSummary(
                    count: due.length, onStart: () => startReview(due)),
                const SizedBox(height: 22),
              ],
              Row(children: [
                Text('내 단어', style: context.texts.titleLarge),
                const SizedBox(width: 6),
                // 갈래를 거르면 목록은 줄어드는데 숫자는 전체를 세고
                // 있었다(5차 452). '직접 추가'로 걸러 두 개만 보이는데
                // 머리줄은 '내 단어 6'이라 어느 쪽이 맞는지 알 수 없었다.
                Text(
                  wordCountLabel(
                    shown: visible.length,
                    all: languageWords.length,
                    filtered: category != categories.first,
                  ),
                  key: const ValueKey('word-count'),
                  style: context.texts.titleMedium
                      .copyWith(color: colors.onSurfaceVariant),
                ),
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
                // 거르다 비면 거르기를 풀 길을 같이 준다(5차 452).
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Text(wordFilterEmptyText,
                          textAlign: TextAlign.center,
                          style: context.texts.bodySmall
                              .copyWith(color: colors.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      TextButton(
                        key: const ValueKey('word-filter-clear'),
                        onPressed: () =>
                            setState(() => category = categories.first),
                        child: const Text(wordFilterClearLabel),
                      ),
                    ],
                  ),
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
            ])),
          ),
        ],
      ),
    );
  }
}

/// 저장 결과를 알릴 한 줄. 시트 안에 적을 때도 같은 말을 쓴다(5차 390).
String wordAddResultText(WordAddResult result) => switch (result) {
      WordAddResult.added => '단어를 저장했어요.',
      WordAddResult.duplicate => '이미 저장한 단어예요.',
      WordAddResult.savedOnDevice => '서버에 저장하지 못해 이 기기에 저장했어요.',
    };

/// 저장 결과를 한 줄로 알린다. 시트가 떠 있지 않을 때만 쓴다.
void showWordAddResult(BuildContext context, WordAddResult result) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(wordAddResultText(result))));
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
    // 단계는 SM-2에서 계속 오를 수 있어 글자는 그대로 적고, 점만 다섯 칸까지 찬다(5차).
    final step = review?.step ?? 0;
    final dots = step.clamp(0, WordReviewStore.intervals.length);
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
            // 복습 단계: 알아요를 누를 때마다 점이 하나씩 찬다. 점만 있으면
            // 무엇을 세는지 알 수 없어 글자도 함께 보여 준다(5차). 문장 목록이
            // 'Lv.1 낯선'을 적는 것과 같은 결이다.
            // 언제 다시 나오는지 함께 적는다(5차, 사용자 요청). 전에는 단계만
            // 보여서 이 단어를 언제 또 보는지 알 수 없었다.
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  wordReviewStepLabel(step),
                  style: context.texts.labelSmall
                      .copyWith(color: colors.onSurfaceVariant),
                ),
                Text(
                  WordReviewStore.nextSeenLabel(review?.dueAt, DateTime.now()),
                  key: ValueKey('word-due-${word.id}'),
                  style: context.texts.labelSmall.copyWith(
                      color: colors.onSurfaceVariant.withValues(alpha: 0.8)),
                ),
              ],
            ),
            const SizedBox(width: 6),
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
                      color: i < dots
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
      actionWidth: swipeActionSlotWidth,
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
                  Text('지우기',
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

/// 단어를 지우기 전에 한 번 묻는다(5차 401).
///
/// 문장은 두 곳에서 모두 물으면서 단어는 밀어서 지우기도, 상세의 '단어
/// 지우기'도 누르는 순간 사라졌다. 뜻·유의어·예문과 복습 진도까지 함께
/// 없어지는데 되돌릴 수 없다.
Future<bool> confirmDeleteWord(BuildContext context, String word) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const ValueKey('delete-word-confirm'),
      title: Text("'$word' 단어를 지울까요?"),
      content: const Text('뜻과 유의어, 예문과 복습 기록도 함께 사라져요.\n$cannotUndoMessage'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소')),
        FilledButton(
          key: const ValueKey('delete-word-ok'),
          style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('지우기'),
        ),
      ],
    ),
  );
  return ok == true;
}

/// 단어 상세 창을 띄운다. 보관함 검색처럼 단어 탭 밖에서 열 때 쓴다(5차).
/// 지우면 [MyWordStore.revision]이 올라가 단어 탭도 다시 읽는다.
Future<void> showWordDetails(
  BuildContext context, {
  required MyWord word,
  required String accountId,
  SentenceAssist? assist,
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
      assist: assist,
      onDelete: () async {
        if (!context.mounted) return;
        if (!await confirmDeleteWord(context, word.word)) return;
        await MyWordStore.remove(accountId, word.id);
        messenger
            ?.showSnackBar(SnackBar(content: Text("'${word.word}' 단어를 지웠어요.")));
      },
    ),
  );
}

/// 복습을 끝내지 않고 창을 닫았을 때 알려 줄 말(5차 515, 사용자 요청).
///
/// 고른 답은 그때그때 저장되는데 창을 내리면 아무 말이 없어서, 한 것이
/// 날아간 줄 알기 쉬웠다. 한 문제도 안 풀었으면 알릴 것이 없으니 비운다.
String? wordReviewPartialMessage(int solved) =>
    solved <= 0 ? null : '$solved문제 풀었어요';

/// 복습 단계를 적는 말. 목록 줄과 상세가 같이 쓴다(5차 482).
@visibleForTesting
String wordReviewStepLabel(int step) => step == 0 ? '복습 전' : '복습 $step단계';

/// 단어 상세의 다음 복습 안내. 기한은 그날 0시로 저장되므로(dueDayAfter) 달력
/// 날짜로 센다(5차). 예전엔 지금 시각과의 차이(inDays)로 세어 밤 11시에 '내일 0시'
/// 기한이 '오늘 복습할 단어'로, 이틀 뒤가 '1일 뒤'로 나왔다.
///
/// 기한만 말한다(5차 482). 전에는 기한이 없으면 '아직 복습 전'이라 단계
/// 이야기를 했고, 그래서 상세는 단계를 따로 적지 않았다. 그 바람에 한 번도
/// 복습 안 한 단어인데 기한만 있으면('오늘 복습할 단어') 목록이 말하는
/// '복습 전'이 상세에서 사라졌다. 기한이 없는 것도 목록처럼 오늘로 본다.
@visibleForTesting
String wordDueLabel(DateTime? due, DateTime now) {
  if (due == null) return '오늘 복습할 단어';
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
/// 한 줄짜리 값을 고치는 창. 뜻과 발음이 함께 쓴다(5차 468).

/// 예문을 적거나 고치는 작은 창(5차 338, 사용자 요청).
///
/// 전에는 단어를 만들 때만 예문을 적을 수 있었다. 이미 만든 단어는 문장에서
/// 저장할 때나 예문이 붙었고, 직접 더하거나 오타를 고칠 길이 없었다.
class WordExampleDialog extends StatefulWidget {
  const WordExampleDialog({super.key, required this.word, this.example});

  final String word;

  /// 고칠 예문. 비우면 새로 적는 것이다.
  final WordExample? example;

  @override
  State<WordExampleDialog> createState() => _WordExampleDialogState();
}

class _WordExampleDialogState extends State<WordExampleDialog> {
  late final _text = TextEditingController(text: widget.example?.text ?? '');
  late final _translation =
      TextEditingController(text: widget.example?.translation ?? '');
  String? _hint;

  @override
  void dispose() {
    _text.dispose();
    _translation.dispose();
    super.dispose();
  }

  void _save() {
    final text = _text.text.trim();
    if (text.isEmpty) {
      setState(() => _hint = '예문을 적어야 저장할 수 있어요.');
      return;
    }
    Navigator.pop(
      context,
      WordExample(
        text: text,
        translation: _translation.text.trim(),
        // 문장에서 저장한 예문이면 그 문장과의 연결을 그대로 둔다.
        sourceSentenceId: widget.example?.sourceSentenceId ?? '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.example == null ? '예문 추가' : '예문 고치기'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey('word-example-input'),
              controller: _text,
              autofocus: true,
              maxLines: 3,
              minLines: 1,
              maxLength: exampleMaxLength,
              decoration: InputDecoration(
                labelText: '예문',
                hintText: widget.word,
              ),
            ),
            TextField(
              key: const ValueKey('word-example-translation-input'),
              controller: _translation,
              maxLines: 2,
              minLines: 1,
              maxLength: exampleMaxLength,
              decoration:
                  const InputDecoration(labelText: meaningOptionalLabel),
            ),
            if (_hint != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _hint!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error, fontSize: 12),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const ValueKey('word-example-save'),
            onPressed: _save,
            child: const Text('저장'),
          ),
        ],
      );
}

/// 유의어를 하나씩 넣는 칸(5차, 사용자 요청).
///
/// 전에는 한 줄에 쉼표로 적게 했는데, 쉼표를 찍어야 하는 줄 모르면 한 덩어리로
/// 저장됐다. '추가'를 누르면 칩으로 쌓이고, 칩의 ×로 하나씩 뺀다.
class SynonymEditor extends StatefulWidget {
  const SynonymEditor({
    super.key,
    required this.synonyms,
    required this.onChanged,
  });

  final List<String> synonyms;
  final ValueChanged<List<String>> onChanged;

  @override
  State<SynonymEditor> createState() => _SynonymEditorState();
}

class _SynonymEditorState extends State<SynonymEditor> {
  final _input = TextEditingController();
  String? _hint;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _add() {
    // 붙여넣기로 'big, large'가 들어올 수 있어 쉼표도 그대로 받아 준다.
    final typed = parseSynonymInput(_input.text);
    if (typed.isEmpty) {
      setState(() => _hint = '넣을 유의어를 적어 주세요.');
      return;
    }
    final next = [...widget.synonyms];
    var skippedSame = false;
    for (final one in typed) {
      if (next.length >= synonymsMaxCount) {
        setState(() => _hint = '유의어는 $synonymsMaxCount개까지 넣을 수 있어요.');
        break;
      }
      if (next.contains(one)) {
        skippedSame = true;
        continue;
      }
      next.add(one);
    }
    if (next.length == widget.synonyms.length) {
      setState(() => _hint = skippedSame ? '이미 넣은 유의어예요.' : _hint);
      return;
    }
    _input.clear();
    setState(() => _hint = skippedSame ? '이미 넣은 것은 빼고 넣었어요.' : null);
    widget.onChanged(next);
  }

  void _remove(String one) {
    widget.onChanged([...widget.synonyms]..remove(one));
    setState(() => _hint = null);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final full = widget.synonyms.length >= synonymsMaxCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('word-synonyms'),
                controller: _input,
                maxLength: synonymMaxLength,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _add(),
                decoration: InputDecoration(
                  labelText: '유의어 (비워도 돼요)',
                  hintText: '하나씩 적고 추가 — big',
                  counterText: '${widget.synonyms.length}/$synonymsMaxCount',
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: FilledButton.tonal(
                key: const ValueKey('add-synonym'),
                // 꽉 찼어도 눌리게 두고 까닭을 적는다(5차).
                onPressed: _add,
                child: Text(full ? '추가' : '추가'),
              ),
            ),
          ],
        ),
        if (widget.synonyms.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: -4,
            children: [
              for (final one in widget.synonyms)
                InputChip(
                  key: ValueKey('synonym-chip-$one'),
                  label: Text(one),
                  onDeleted: () => _remove(one),
                  deleteButtonTooltipMessage: '$one 빼기',
                ),
            ],
          ),
        if (_hint case final hint?)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              hint,
              key: const ValueKey('synonym-hint'),
              style: context.texts.bodySmall
                  .copyWith(color: colors.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

/// 유의어를 적는 창. 뜻 고치기 창과 같은 모양으로 둔다(5차).

class _WordDetailSheet extends StatefulWidget {
  const _WordDetailSheet({
    required this.word,
    required this.review,
    required this.accountId,
    required this.onDelete,
    this.assist,
  });

  final MyWord word;
  final WordReview? review;
  final String accountId;
  final VoidCallback onDelete;

  /// 테스트에서 가짜를 넣는 자리. 비우면 서버를 부른다.
  final SentenceAssist? assist;

  @override
  State<_WordDetailSheet> createState() => _WordDetailSheetState();
}

class _WordDetailSheetState extends State<_WordDetailSheet> {
  late String meaning = widget.word.meaning;
  late String pronunciation = widget.word.pronunciation;
  /// 시트 안에 적는 알림. 스낵바는 시트 뒤에 깔려 보이지 않는다(5차 392).
  String? notice;
  Timer? noticeTimer;

  /// 잠시 뒤 스스로 사라지고, 누르면 바로 사라진다. 문장 상세와 같다(390).
  void showNotice(String message) {
    if (!mounted) return;
    setState(() => notice = message);
    noticeTimer?.cancel();
    noticeTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => notice = null);
    });
  }

  @override
  void dispose() {
    noticeTimer?.cancel();
    super.dispose();
  }

  late List<String> synonyms = widget.word.synonyms;
  late List<WordExample> examples = widget.word.examples;

  /// 유의어를 적거나 고친다. 추가할 때만 적을 수 있으면 나중에 알게 된
  /// 유의어를 넣을 길이 없다(5차).

  /// 예문을 새로 적는다(5차 338, 사용자 요청).

  /// 뜻과 예문을 한 번에 받아 넣는다(5차 467, 사용자 요청).
  ///
  /// 직접 더한 낱말에는 예문이 없어서 쓰임을 볼 길이 없었다. 서버에
  /// 지금 들고 있는 예문을 함께 보내, 그것과 겹치지 않는 것만 받는다.

  /// 몇 개를 받을지 고른다. 남은 자리보다 많이 고를 수 없다.
  ///
  /// 전에는 AlertDialog에 단추를 세로로 쌓았는데, 여섯 개가 한 줄씩
  /// 서서 창이 길쭉하고 어디를 눌러야 할지 잘 안 보였다(5차 468).
  /// 아래에서 올라오는 고르기 시트로 둔다.

  /// 예문 하나를 고친다(5차 338, 사용자 요청).

  /// 예문 하나를 뺀다. 되돌릴 수 없으니 한 번 묻는다(5차 328).

  /// 뜻을 적거나 고친다. 전에는 뜻이 비어 있으면 지우고 다시 넣는 수밖에
  /// 없었다(문장에서 단어만 고르면 뜻이 비어 있다, 5차).

  /// 뜻·발음·유의어·예문을 한 창에서 고친다(5차 469, 사용자 요청).
  ///
  /// 전에는 항목마다 작은 창이 따로 떴다. 한 낱말을 손보려면 창을 네 번
  /// 열었다 닫아야 했다.
  Future<void> _editWord() async {
    final next = await showWordEditSheet(
      context,
      word: widget.word.copyWith(
        meaning: meaning,
        pronunciation: pronunciation,
        synonyms: synonyms,
        examples: examples,
      ),
      accountId: widget.accountId,
      assist: widget.assist,
    );
    if (!mounted || next == null) return;
    setState(() {
      meaning = next.meaning;
      pronunciation = next.pronunciation;
      synonyms = next.synonyms;
      examples = next.examples;
    });
  }

  /// 발음을 적거나 고친다(5차 468, 사용자 요청).

  @override
  Widget build(BuildContext context) {
    final word = widget.word;
    final review = widget.review;
    final colors = Theme.of(context).colorScheme;
    final muted =
        context.texts.bodySmall.copyWith(color: colors.onSurfaceVariant);
    final sheetNotice = notice;
    return SafeArea(
      child: Stack(
        children: [
          // 발음 줄이 늘고 예문도 10개까지 들어가면서 시트가 넘쳤다.
          // 길어지면 안에서 밀어 볼 수 있게 한다(5차 468).
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child:
                          Text(word.word, style: context.texts.headlineSmall),
                    ),
                    // 단어에는 소리가 아예 없었다. 문장 상세와 같은 단추를 둔다
                    // (5차 320).
                    SpeakControls(
                      text: word.word,
                      language: word.language,
                      speakKey: const ValueKey('speak-word'),
                      repeatKey: const ValueKey('repeat-word'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(meaning.isEmpty ? '뜻을 아직 적지 않았어요' : meaning,
                          key: const ValueKey('word-detail-meaning'),
                          style: context.texts.bodyLarge.copyWith(
                              color: meaning.isEmpty
                                  ? colors.onSurfaceVariant
                                  : null)),
                    ),
                    // 뜻·발음·유의어·예문을 한 창에서 고친다(5차 469).
                    TextButton(
                      key: const ValueKey('edit-word'),
                      onPressed: _editWord,
                      child: const Text('고치기'),
                    ),
                  ],
                ),
                // 발음 줄. 뜻과 같은 꼴로 둔다(5차 468, 사용자 요청).
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                          pronunciation.isEmpty
                              ? '발음을 아직 적지 않았어요'
                              : pronunciation,
                          key: const ValueKey('word-detail-pronunciation'),
                          style: context.texts.bodyMedium.copyWith(
                              color: colors.onSurfaceVariant)),
                    ),
                  ],
                ),
                // 유의어는 칩으로 한 줄에 모아 보여 준다(5차, 사용자 요청).
                // 없어도 적을 수 있게 줄은 늘 둔다.
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: Text('유의어', style: muted)),
                  ],
                ),
                if (synonyms.isEmpty)
                  Text('아직 적지 않았어요',
                      key: const ValueKey('word-detail-synonyms-empty'),
                      style: muted)
                else ...[
                  const SizedBox(height: 2),
                  Wrap(
                    key: const ValueKey('word-detail-synonyms'),
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final one in synonyms)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest
                                .withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(one, style: context.texts.bodySmall),
                        ),
                    ],
                  ),
                ],
                // 예문은 여러 개일 수 있다(5차).
                for (final (index, example) in examples.indexed) ...[
                  SizedBox(height: index == 0 ? 16 : 8),
                  Container(
                    key: ValueKey('word-detail-example-$index'),
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:
                          colors.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 예문을 누르면 고치기 창이 열린다. 거기서 뜻·발음·
                        // 유의어까지 한 번에 손본다(5차 469).
                        Expanded(
                          child: InkWell(
                            key: ValueKey('edit-word-example-$index'),
                            onTap: _editWord,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(example.text,
                                      style: context.texts.bodyMedium.copyWith(
                                          fontWeight: FontWeight.w700)),
                                  if (example.translation.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(example.translation, style: muted),
                                  ],
                                ]),
                          ),
                        ),
                        // 더할 수는 있는데 뺄 길이 없었다(5차 328).
                      ],
                    ),
                  ),
                ],
                // 이 화면은 보기만 한다(5차 472, 사용자 결정). 고치거나
                // 자동으로 채우는 것은 '고치기' 창에서 한다.
                const SizedBox(height: 8),
                Text(
                    [
                      if (word.sourceSentenceId.isNotEmpty) '문장에서 저장',
                      // 목록 줄과 똑같이 적는다(5차 482). 전에는 단계가
                      // 0이면 빼고 기한 글에 '아직 복습 전'을 맡겼는데,
                      // 기한이 있는 새 단어는 그 말이 통째로 사라졌다.
                      wordReviewStepLabel(review?.step ?? 0),
                      wordDueLabel(review?.dueAt, DateTime.now()),
                    ].join(' · '),
                    key: const ValueKey('word-detail-meta'),
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
          // 시트 안에 띄운다. 아래가 아니라 위에 둬야 '단어 지우기' 같은
          // 맨 밑 단추를 가리지 않는다(5차 392).
          if (sheetNotice != null)
            Positioned(
              left: 16,
              right: 16,
              top: 8,
              child: GestureDetector(
                onTap: () {
                  noticeTimer?.cancel();
                  setState(() => notice = null);
                },
                child: Material(
                  color: colors.inverseSurface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    child: Text(
                      sheetNotice,
                      key: const ValueKey('word-detail-notice'),
                      style: context.texts.bodyMedium
                          .copyWith(color: colors.onInverseSurface),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 단어 직접 추가. 단어만 넣어도 저장된다(뜻·예문은 선택).
/// '웹에서 찾기'를 단어 없이 눌렀을 때.
const String wordSearchNeedsWordHint = '먼저 찾을 단어를 적어 주세요.';

/// 뜻을 이미 적어 둔 채로 '뜻 채우기'를 눌렀을 때(5차 368).
///
/// 전에는 서버에 묻고(하루 횟수를 써 놓고) 이미 적은 뜻은 덮지 않아서
/// 아무 일도 일어나지 않은 것처럼 보였다.
const String wordMeaningAlreadyHint = '이미 뜻이나 발음을 적어 두셨어요. 지우고 누르면 채워 드려요.';

/// '단어 추가' 시트의 저장 버튼이 꺼져 있는 까닭.
const String addWordNeedsWordHint = '단어를 적어야 저장할 수 있어요.';

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

  /// 한글 발음. 자동 채우기가 함께 채운다(5차 468, 사용자 요청).
  final _pronunciation = TextEditingController();

  /// 유의어·동의어. '추가'를 눌러 하나씩 넣는다(5차, 사용자 요청).
  List<String> _synonymList = const [];

  /// 예문 입력칸. 같은 단어를 여러 문장에서 만나므로 여러 개를 적을 수 있다(5차).
  late final List<TextEditingController> _examples = [
    TextEditingController(text: widget.example)
  ];

  /// 예문마다 뜻 입력칸. 나중에 고칠 때는 뜻을 적을 수 있는데 처음 만들 때는
  /// 없어서 짝이 맞지 않았다(5차 344, 사용자 지적).
  late final List<TextEditingController> _exampleMeanings = [
    TextEditingController(text: widget.exampleTranslation)
  ];
  late final SentenceAssist _assist = widget.assist ?? CloudSentenceAssist();
  bool saving = false;
  bool filling = false;
  bool fillingExamples = false;

  /// 뜻 채우기 결과를 칸 아래에 적는다(5차 368).
  ///
  /// 전에는 SnackBar로 알렸는데, 이 화면은 바텀시트라 시트가 아래를 덮어
  /// 사용자에게 보이지 않았다. 시트 안에 적어야 보인다.
  String? fillNote;

  /// 뜻과 발음을 서버에 물어 채운다(5차 472, 사용자 요청).
  ///
  /// 예문은 따로 받는다. 뜻·발음은 한 번 채우면 끝이고 예문은 여러 개를
  /// 더 받는 것이라, 한 단추로 묶으면 무엇에 횟수를 쓰는지 흐려진다.
  /// 이미 적어 둔 칸은 덮지 않는다.
  Future<void> fillMeaning() async {
    final word = _word.text.trim();
    if (word.isEmpty || filling) return;
    // 하나라도 적혀 있으면 채우지 않는다(5차 554, 사용자 결정). 고치기
    // 시트·문장 추가와 같은 규칙이다.
    if (_basicsTyped) {
      setState(() => fillNote = wordMeaningAlreadyHint);
      return;
    }
    setState(() {
      filling = true;
      fillNote = null;
    });
    String? note;
    try {
      // count 0이면 서버가 예문을 만들지 않는다(5차 472).
      final suggestion = await _assist.suggestWord(
        language: widget.language,
        word: word,
        count: 0,
      );
      if (!mounted) return;
      final meaning = suggestion.translation?.trim() ?? '';
      final sound = suggestion.pronunciation?.trim() ?? '';
      if (_meaning.text.trim().isEmpty && meaning.isNotEmpty) {
        _meaning.text = meaning;
      }
      if (_pronunciation.text.trim().isEmpty && sound.isNotEmpty) {
        _pronunciation.text = sound;
      }
      if (meaning.isEmpty && sound.isEmpty) {
        note = '뜻을 찾지 못했어요. 직접 적어 주세요.';
      }
    } on SentenceAssistQuotaExceeded {
      note = assistQuotaExhaustedMessage;
    } on SentenceAssistUnavailable catch (e) {
      note = e.reason;
    } catch (_) {
      note = '뜻을 채우지 못했어요. 직접 적어 주세요.';
    } finally {
      if (mounted) {
        setState(() {
          filling = false;
          fillNote = note;
        });
      }
    }
  }

  /// 예문만 서버에 물어 받는다(5차 472, 사용자 요청).
  ///
  /// 지금 칸에 적힌 예문을 겹치지 않게 함께 보낸다.
  Future<void> fillExamples() async {
    final word = _word.text.trim();
    if (word.isEmpty || fillingExamples) return;
    // 상한을 모르면 묻기 전에 서버에 물어 온다(5차 507).
    if (_assist.maxExamplesPerWord == null) {
      setState(() => fillingExamples = true);
      await _assist.refreshUsage();
      if (!mounted) return;
      setState(() => fillingExamples = false);
    }
    if (_assist.examplesRemainingToday == 0) {
      // 까닭은 _examplesBlocked가 단추 바로 아래에 적는다. fillNote에도
      // 넣으면 시트 아래에 똑같은 말이 한 번 더 나온다(5차 513).
      setState(() {});
      return;
    }
    final emptySlots = [
      for (final (index, c) in _examples.indexed)
        if (c.text.trim().isEmpty) index,
    ];
    final cap = _assist.maxExamplesPerWord ?? examplesMaxCount;
    final room = cap - _examples.length;
    if (emptySlots.isEmpty && room <= 0) {
      // 위와 같다. 낱말당 상한도 _examplesBlocked가 이미 적는다(5차 513).
      setState(() {});
      return;
    }
    // 몇 개를 받을지 고르게 한다. 상한도 여기서 보여 준다(5차 474).
    final already = [
      for (final c in _examples)
        if (c.text.trim().isNotEmpty) c,
    ].length;
    final count = await askExampleCount(
      context,
      room: emptySlots.length + room < 1 ? 1 : emptySlots.length + room,
      already: already,
      maxPerWord: _assist.maxExamplesPerWord,
      remainingToday: _assist.examplesRemainingToday,
      exampleCredits: _assist.exampleCredits,
    );
    if (!mounted || count == null) return;

    setState(() {
      fillingExamples = true;
      fillNote = null;
    });
    String? note;
    try {
      final suggestion = await _assist.suggestWord(
        language: widget.language,
        word: word,
        existingExamples: [
          for (final c in _examples)
            if (c.text.trim().isNotEmpty) c.text.trim(),
        ],
        count: count,
      );
      if (!mounted) return;
      var slot = 0;
      for (final example in suggestion.examples) {
        if (slot < emptySlots.length) {
          final at = emptySlots[slot];
          _examples[at].text = example.text;
          _exampleMeanings[at].text = example.translation;
        } else {
          if (_examples.length >= examplesMaxCount) break;
          _examples.add(TextEditingController(text: example.text));
          _exampleMeanings
              .add(TextEditingController(text: example.translation));
        }
        slot++;
      }
      if (suggestion.examples.isEmpty) {
        note = '예문을 받지 못했어요. 잠시 뒤 다시 해 주세요.';
      }
    } on SentenceAssistQuotaExceeded catch (e) {
      // 예문 한도와 뜻·발음 한도는 다른 축이다. 다 쓴 쪽을 적는다(5차 517).
      note =
          e.examples ? exampleQuotaExhaustedText : assistQuotaExhaustedMessage;
    } on SentenceAssistUnavailable catch (e) {
      note = e.reason;
    } catch (_) {
      note = '예문을 받지 못했어요. 잠시 뒤 다시 해 주세요.';
    } finally {
      if (mounted) {
        setState(() {
          fillingExamples = false;
          fillNote = note;
        });
      }
    }
  }

  /// 웹 사전을 앱 안에서 연다. 단어를 적지 않았으면 까닭을 알린다(5차).
  void _openWebSearch() {
    final word = _word.text.trim();
    if (word.isEmpty) {
      // 토스트는 시트 뒤에 깔려 보이지 않았다. 시트 안에 적는다(5차 391).
      setState(() => fillNote = wordSearchNeedsWordHint);
      return;
    }
    if (fillNote == wordSearchNeedsWordHint) setState(() => fillNote = null);
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => WebDocumentScreen(
          title: wordSearchTitle(word),
          url: wordSearchUrl(
            language: widget.language,
            word: word,
            site: AppConfig.wordSearchSite,
          ),
        ),
      ),
    );
  }

  /// 서버에서 횟수를 받아왔는지. 못 받아오면 안내를 지운다.
  bool _usageChecked = false;
  bool _usageFailed = false;

  /// 아직 횟수를 묻는 중인지. 묻는 동안에는 채우기 단추를 막는다(5차 515).
  ///
  /// 전에는 '횟수 확인 중…'이 떠 있는데도 단추가 눌렸다. 그때는 한도를
  /// 모르니 다 쓴 사람도 누를 수 있었고, 눌러서야 막혔다는 걸 알았다.
  /// 성공이든 실패든 한 번 끝나면 다시 열어 준다.
  bool _usageLoading = true;

  /// 오늘 횟수를 다 썼나. 다 썼으면 단추를 막는다(5차 473).
  bool get _exhausted => assistExhausted(
        used: _assistUsed,
        limit: _assist.dailyLimit,
        credits: _assist.assistCredits ?? 0,
      );

  /// 오늘 예문을 다 만들었나. 뜻·발음 채우기 횟수와는 다른 한도다.
  bool get _examplesExhausted => _assist.examplesRemainingToday == 0;

  /// 예문 단추가 막힌 까닭. 없으면 null.
  String? get _examplesBlocked {
    if (_examplesExhausted) return exampleQuotaExhaustedText;
    final cap = _assist.maxExamplesPerWord;
    if (cap == null) return null;
    final filled = [
      for (final c in _examples)
        if (c.text.trim().isNotEmpty) c,
    ].length;
    if (filled >= cap && _examples.length >= cap) {
      return exampleFillCapText(cap);
    }
    return null;
  }

  /// 단추 아래에 적을 말. 막혀 있으면 까닭부터 말한다(5차 474).
  /// 뜻이나 발음을 손으로 적어 두었는지(5차 554).
  ///
  /// fillMeaning은 이때 서버를 부르지 않고 돌아선다. 그런데 단추는 파랗게
  /// 켜진 채였고 안내도 '한 번만 채우면 돼요'여서, 눌러도 아무 일이 없는
  /// 것처럼 보였다. 고치기 시트에서 이미 고친 결함이 이쪽에 남아 있었다
  /// (5차 506·515·519·526과 같은 결).
  bool get _basicsTyped =>
      _meaning.text.trim().isNotEmpty ||
      _pronunciation.text.trim().isNotEmpty;

  String _fillHint(String whenReady) {
    if (_word.text.trim().isEmpty) return wordFillNeedsWordHint;
    if (_exhausted) return assistQuotaExhaustedMessage;
    if (_basicsTyped) return wordFillBasicsDoneHint;
    return whenReady;
  }

  /// 예문 단추 아래에 적을 말. 예문 한도로 판단한다.
  String _fillExamplesHint() {
    if (_word.text.trim().isEmpty) return wordFillNeedsWordHint;
    // 뜻·발음 쪽은 단추 옆 '오늘 N/M회 사용' 자리가 '횟수 확인 중…'을
    // 대신 적어 준다. 예문 쪽에는 그 자리가 없어 여기서 적는다(5차 519).
    return assistFillHint(
      loading: _usageLoading,
      whenReady: _examplesBlocked ?? wordFillExamplesHint,
    );
  }

  /// 오늘 쓴 횟수. 서버에서 못 받아오면 null.
  int? get _assistUsed => assistUsedToday(
        limit: _assist.dailyLimit,
        remaining: _assist.remainingToday,
        credits: _assist.assistCredits ?? 0,
      );

  @override
  void initState() {
    super.initState();
    _word.addListener(() => setState(() {}));
    // 뜻·발음도 들어야 한다(5차 554). 하나라도 적히면 채우기 단추를 끄는데,
    // 듣지 않으면 다른 일로 다시 그려질 때까지 켜진 채로 남는다.
    _meaning.addListener(() => setState(() {}));
    _pronunciation.addListener(() => setState(() {}));
    // 횟수만 가져온다(모델을 부르지 않으므로 한 번도 쓰지 않는다).
    // 못 가져오면 '확인 중'에 갇히지 않게 안내를 지운다.
    _assist.refreshUsage().then((_) {
      if (mounted) {
        setState(() {
          _usageChecked = true;
          _usageLoading = false;
        });
      }
    }).catchError((_) {
      if (mounted) {
        setState(() {
          _usageFailed = true;
          _usageLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _word.dispose();
    _meaning.dispose();
    _pronunciation.dispose();
    for (final c in [..._examples, ..._exampleMeanings]) {
      c.dispose();
    }
    super.dispose();
  }

  void addExampleField() {
    if (_examples.length >= examplesMaxCount) return;
    setState(() {
      _examples.add(TextEditingController());
      _exampleMeanings.add(TextEditingController());
    });
  }

  void removeExampleField(int index) {
    if (_examples.length <= 1) return;
    setState(() {
      _examples.removeAt(index).dispose();
      _exampleMeanings.removeAt(index).dispose();
    });
  }

  Future<void> save() async {
    if (saving || _word.text.trim().isEmpty) return;
    setState(() => saving = true);
    final result = await MyWordStore.add(
      widget.accountId,
      language: widget.language,
      word: _word.text,
      meaning: _meaning.text,
      pronunciation: _pronunciation.text,
      synonyms: clipWordSynonyms(_synonymList),
      examples: [
        for (final (index, c) in _examples.indexed)
          WordExample(
            text: c.text,
            // 적은 뜻을 쓰고, 비어 있으면 미리 채워 준 문장의 뜻을 쓴다.
            translation: _exampleMeanings[index].text.trim().isNotEmpty
                ? _exampleMeanings[index].text
                : (c.text.trim() == widget.example.trim()
                    ? widget.exampleTranslation
                    : ''),
            // 미리 채워 준 문장은 그 문장과의 연결을 그대로 붙인다.
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
        // 칸이 늘어 화면이 작으면 넘쳤다(유의어 칩·찾을 곳 고르기, 5차).
        child: SingleChildScrollView(
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
                // 단추를 단어 칸 바로 아래에 둔다(5차 471, 사용자 요청).
                // 전에는 뜻·발음 칸 아래에 있어서 그 둘만 채우는 줄 알았다.
                // 예문 칸은 유의어 다음이라 한참 밑에 있다.
                Row(
                  children: [
                    FilledButton.tonalIcon(
                      key: const ValueKey('fill-word-meaning'),
                      onPressed: _word.text.trim().isEmpty ||
                              filling ||
                              _usageLoading ||
                              _exhausted ||
                              _basicsTyped
                          ? null
                          : fillMeaning,
                      icon: filling
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const AssistIcon(AssistKind.meaning, size: 18),
                      label: const Text(wordFillBasicsLabel),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        wordAssistUsageLabel(
                          used: _assistUsed,
                          limit: _assist.dailyLimit,
                          failed: _usageFailed ||
                              (_usageChecked && _assistUsed == null),
                        ),
                        key: const ValueKey('word-assist-usage'),
                        style: context.texts.bodySmall.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
                Text(
                  _fillHint(wordFillBasicsHint),
                  key: const ValueKey('word-autofill-hint'),
                  style: context.texts.bodySmall.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('word-meaning'),
                  controller: _meaning,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: meaningOptionalLabel,
                    border: OutlineInputBorder(),
                  ),
                ),
                // 발음 칸(5차 468, 사용자 요청). 뜻과 함께 자동으로 찬다.
                TextField(
                  key: const ValueKey('word-pronunciation'),
                  controller: _pronunciation,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: pronunciationOptionalLabel,
                    hintText: '한글로 소리 나는 대로',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (fillNote != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: Text(
                      fillNote!,
                      key: const ValueKey('word-fill-note'),
                      style: context.texts.bodySmall
                          .copyWith(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                // 뜻을 서버에 물어보는 것 말고, 웹 사전을 직접 열어 보고
                // 싶을 때가 있다(5차, 사용자 요청). 패롯이 들지 않는다.
                // 어디서 찾을지도 고를 수 있다(5차, 사용자 요청).
                Row(
                  children: [
                    FilledButton.tonalIcon(
                      key: const ValueKey('search-word-web'),
                      onPressed: _openWebSearch,
                      icon: const Icon(Icons.travel_explore_rounded, size: 18),
                      label: const Text('웹에서 찾기'),
                    ),
                    const SizedBox(width: 4),
                    PopupMenuButton<WordSearchSite>(
                      key: const ValueKey('word-search-site'),
                      tooltip: '어디서 찾을지 고르기',
                      initialValue: AppConfig.wordSearchSite,
                      onSelected: (site) {
                        setState(() => AppConfig.wordSearchSite = site);
                        AppConfig.saveToPrefs();
                      },
                      itemBuilder: (context) => [
                        for (final site in WordSearchSite.values)
                          PopupMenuItem<WordSearchSite>(
                            key: ValueKey('word-search-site-${site.name}'),
                            value: site,
                            child: Text(
                                wordSearchSiteLabel(site, widget.language)),
                          ),
                      ],
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            AppConfig.wordSearchSite.label,
                            key: const ValueKey('word-search-site-label'),
                            style: context.texts.bodySmall.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                          ),
                          const Icon(Icons.arrow_drop_down_rounded, size: 18),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SynonymEditor(
                  synonyms: _synonymList,
                  onChanged: (next) => setState(() => _synonymList = next),
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
                          ? '예문 (비워도 돼요)'
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
                  const SizedBox(height: 6),
                  // 예문 뜻. 고치는 창과 같은 칸을 처음 만들 때도 둔다(5차 344).
                  TextField(
                    key: ValueKey('word-example-meaning-$index'),
                    controller: _exampleMeanings[index],
                    maxLength: 300,
                    maxLines: 2,
                    minLines: 1,
                    decoration: const InputDecoration(
                      labelText: '예문 뜻 (비워도 돼요)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                // 예문 단추는 예문 칸 옆에 둔다(5차 472, 사용자 요청).
                // 뜻·발음 단추는 맨 위에 있다. 쓰임이 다르니 자리도 나눈다.
                Row(
                  children: [
                    if (_examples.length < examplesMaxCount)
                      TextButton.icon(
                        key: const ValueKey('add-word-example'),
                        onPressed: addExampleField,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('예문 더 넣기'),
                      ),
                    TextButton.icon(
                      key: const ValueKey('fill-word-examples'),
                      onPressed: _word.text.trim().isEmpty ||
                              fillingExamples ||
                              _usageLoading ||
                              _examplesBlocked != null
                          ? null
                          : fillExamples,
                      icon: fillingExamples
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const AssistIcon(AssistKind.example, size: 18),
                      label: const Text(wordFillExamplesLabel),
                    ),
                  ],
                ),
                Text(
                  _fillExamplesHint(),
                  key: const ValueKey('word-examples-hint'),
                  style: context.texts.bodySmall.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                // 버튼이 왜 꺼져 있는지 적는다(5차, 새 클립 화면과 같게).
                // 예전에는 흐린 채 눌러도 아무 일이 없었다.
                if (_word.text.trim().isEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    addWordNeedsWordHint,
                    key: const ValueKey('save-word-hint'),
                    textAlign: TextAlign.center,
                    style: context.texts.bodySmall.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 오늘 복습. 단어를 보고 뜻을 떠올린 뒤 "뜻 보기", 그다음 "다시"/"알아요".
/// 마친 화면에 적는 결과 한 줄. 단어와 고른 답을 나란히 둔다(5차 509).
class _ReviewResultRow extends StatelessWidget {
  const _ReviewResultRow({required this.word, required this.rating});

  final MyWord word;
  final ReviewRating rating;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final known = rating != ReviewRating.again;
    return Row(
      children: [
        Icon(
          known ? Icons.check_rounded : Icons.refresh_rounded,
          size: 18,
          color: known ? colors.primary : colors.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            word.word,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.texts.bodyMedium,
          ),
        ),
        if (word.meaning.trim().isNotEmpty) ...[
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              word.meaning.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: context.texts.bodySmall
                  .copyWith(color: colors.onSurfaceVariant),
            ),
          ),
        ],
        const SizedBox(width: 8),
        Text(
          reviewRatingLabel(rating),
          style: context.texts.labelSmall.copyWith(
              color: known ? colors.primary : colors.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// 고른 답을 적는 말. 버튼에 쓰는 말과 같게 둔다.
String reviewRatingLabel(ReviewRating rating) => switch (rating) {
      ReviewRating.again => '다시',
      ReviewRating.known => '알아요',
      ReviewRating.easy => '쉬워요',
    };

class WordReviewSheet extends StatefulWidget {
  const WordReviewSheet({
    super.key,
    required this.accountId,
    required this.words,
    this.reviews = const {},
  });

  final String accountId;
  final List<MyWord> words;

  /// 지금까지의 복습 상태. 버튼에 '며칠 뒤에 다시 나오는지'를 적는 데 쓴다(5차).
  final Map<String, WordReview> reviews;

  @override
  State<WordReviewSheet> createState() => _WordReviewSheetState();
}

class _WordReviewSheetState extends State<WordReviewSheet> {
  /// 이번 바퀴에서 볼 단어. '다시'를 고른 단어만 모아 한 바퀴 더 돌 수 있다.
  late List<MyWord> queue = widget.words;

  /// 이번 창에서 쌓인 복습 상태. 답할 때마다 갱신해 버튼의 날짜가 맞게 한다.
  late final Map<String, WordReview> reviews = {...widget.reviews};
  int index = 0;
  bool revealed = false;
  int knownCount = 0;

  /// 이번 바퀴에서 '다시'를 고른 단어.
  final List<MyWord> again = [];

  /// 이번 바퀴에 본 단어와 고른 답. 마친 화면에 하나씩 적어 준다(5차 509).
  /// 전에는 '알아요 N개 · 다시 M개'만 적어서, 어떤 단어를 틀렸는지 보려면
  /// 목록으로 돌아가 하나씩 열어 봐야 했다.
  final List<({MyWord word, ReviewRating rating})> answered = [];

  /// 몇 바퀴째인지(0이면 오늘 처음 도는 중). '다시' 고른 것만 다시 돌 때
  /// 화면이 그대로여서 처음부터 다시 하는 것처럼 보였다(5차).
  int round = 0;

  /// 이 창에서 푼 문제 수. '다시' 바퀴를 돌아도 더해진다. 끝내지 않고
  /// 닫을 때 몇 개를 풀었는지 알리는 데 쓴다(5차 515).
  int solvedCount = 0;

  /// 이 창에서 받은 크래커. 다 마친 화면에 적는다(5차 505).
  int earnedCrackers = 0;

  /// 상한에 걸려 깎였으면 어느 상한인지. 없으면 null.
  RewardCap? rewardCap;

  Future<void> answer(ReviewRating rating) async {
    final word = queue[index];
    final known = rating != ReviewRating.again;
    unawaited(WordReviewStore.record(widget.accountId, word.id, rating: rating)
        .then((next) {
      if (mounted) setState(() => reviews[word.id] = next);
    }));
    // 학습 캘린더에도 쌓는다(사용자 요청). 따라 말하기와 다른 자리에 세므로
    // 하루 목표와 칸 색은 그대로다. '다시'도 복습이라 센다(크래커와 같은 셈).
    unawaited(PracticeCalendar.recordWordReview(widget.accountId));
    setState(() {
      answered.add((word: word, rating: rating));
      solvedCount++;
      if (known) {
        knownCount++;
      } else {
        again.add(word);
      }
      index++;
      revealed = false;
    });
    // 한 번 답할 때마다 크래커를 뽑아 준다. '다시'도 복습이라 센다.
    // 상한은 PracticeRewardStore가 지킨다(5차 505).
    final grant = await grantPracticeReward(context, widget.accountId);
    if (!mounted) return;
    setState(() {
      earnedCrackers += grant.crackers;
      if (grant.capped) rewardCap = grant.cap;
    });
    // 이번 바퀴를 다 돌았으면 받은 크래커를 크게 보여 준다(5차 509).
    // 한 바퀴에 한 번만 띄운다. '다시' 고른 것을 또 돌면 그 바퀴 끝에 또 뜬다.
    if (index >= queue.length && earnedCrackers > 0 && !celebrated) {
      celebrated = true;
      await showRewardCelebration(context, crackers: earnedCrackers);
    }
  }

  /// 이번 바퀴에서 덮개를 이미 띄웠는지.
  bool celebrated = false;

  /// 이 답을 고르면 며칠 뒤에 다시 나오는지.
  String nextLabelFor(ReviewRating rating) {
    if (index >= queue.length) return '';
    final review = reviews[queue[index].id];
    return WordReviewStore.intervalLabel(
        WordReviewStore.previewInterval(review, rating));
  }

  /// '다시'로 고른 단어만 다시 돈다. '다시'는 기한을 오늘로 두므로(record)
  /// 전에는 창을 닫고 '시작'을 다시 눌러야 그 단어를 또 볼 수 있었다(5차).
  void reviewAgain() {
    setState(() {
      queue = List.of(again);
      again.clear();
      answered.clear();
      // 이 바퀴도 다 돌면 다시 '짜잔'을 띄운다(5차 509).
      celebrated = false;
      index = 0;
      knownCount = 0;
      revealed = false;
      round++;
    });
  }

  @override
  void dispose() {
    // 다 풀고 나면 마친 화면이 이미 셈을 보여 준다. 중간에 닫았을 때만
    // 알린다. 토스트는 창이 사라진 뒤에 떠야 해서 여기서 부른다(5차 515).
    if (index < queue.length) {
      final message = wordReviewPartialMessage(solvedCount);
      if (message != null) showToast(message);
    }
    super.dispose();
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
              // 중간에 그만둘 길이 시트를 밀어 내리는 것뿐이었다(5차).
              // 다른 창처럼 닫기 버튼을 둔다. 고른 답은 그때그때 저장되니
              // 닫아도 지금까지 한 복습은 남는다.
              IconButton(
                key: const ValueKey('close-word-review'),
                tooltip: '닫기',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ]),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: wordReviewProgress(index: index, total: queue.length),
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
              if (earnedCrackers > 0) ...[
                const SizedBox(height: 6),
                Text(practiceRewardEarned(earnedCrackers),
                    key: const ValueKey('review-earned-crackers'),
                    style: context.texts.labelLarge
                        .copyWith(color: colors.primary)),
              ],
              if (rewardCap != null) ...[
                const SizedBox(height: 6),
                Text(practiceRewardCappedMessage(rewardCap!),
                    key: const ValueKey('review-reward-capped'),
                    textAlign: TextAlign.center,
                    style: context.texts.bodySmall
                        .copyWith(color: colors.onSurfaceVariant)),
              ],
              if (answered.isNotEmpty) ...[
                const SizedBox(height: 16),
                // 본 단어를 하나씩 되짚어 준다. 많으면 이 자리만 넘긴다.
                Flexible(
                  child: ListView.separated(
                    key: const ValueKey('review-result-list'),
                    shrinkWrap: true,
                    itemCount: answered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, i) {
                      final item = answered[i];
                      return _ReviewResultRow(
                        word: item.word,
                        rating: item.rating,
                      );
                    },
                  ),
                ),
              ],
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
              const SizedBox(height: 8),
              // 외우면서 발음도 듣는다. 복습은 한 번만 들으면 되니 반복은 뺀다
              // (5차 329).
              SpeakControls(
                key: ValueKey('review-speak-${queue[index].id}'),
                text: queue[index].word,
                language: queue[index].language,
                speakKey: const ValueKey('speak-review-word'),
                showRepeat: false,
              ),
              const SizedBox(height: 8),
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
                // 얼마나 쉬웠는지에 따라 다음에 나오는 날이 달라진다(5차, SM-2).
                // '쉬워요'는 바로 떠오른 단어라 더 멀리 민다.
                // 고르기 전에 며칠 뒤에 다시 나오는지 적어 둔다(5차, 사용자 요청).
                Row(children: [
                  Expanded(
                    child: _RatingChoice(
                      label: '다시',
                      nextLabel: nextLabelFor(ReviewRating.again),
                      onPressed: () => answer(ReviewRating.again),
                      child: OutlinedButton(
                        key: const ValueKey('review-again'),
                        onPressed: () => answer(ReviewRating.again),
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48)),
                        child: const Text('다시'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _RatingChoice(
                      label: '알아요',
                      nextLabel: nextLabelFor(ReviewRating.known),
                      onPressed: () => answer(ReviewRating.known),
                      child: FilledButton(
                        key: const ValueKey('review-known'),
                        onPressed: () => answer(ReviewRating.known),
                        style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48)),
                        child: const Text('알아요'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _RatingChoice(
                      label: '쉬워요',
                      nextLabel: nextLabelFor(ReviewRating.easy),
                      onPressed: () => answer(ReviewRating.easy),
                      child: FilledButton.tonal(
                        key: const ValueKey('review-easy'),
                        onPressed: () => answer(ReviewRating.easy),
                        style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48)),
                        child: const Text('쉬워요'),
                      ),
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

/// 복습 시트 진행 막대가 채울 몫.
///
/// 머리말이 '1 / 3'이라고 적는 것과 같은 몫을 채운다. 전에는 끝낸 개수
/// (index)를 썼다. 그래서 첫 단어에서 머리말은 '1 / 3'인데 막대는 하나도
/// 차지 않았고, 마지막 단어에서도 2/3만 찼다(5차).
double wordReviewProgress({required int index, required int total}) {
  if (total <= 0) return 1;
  final shown = (index + 1).clamp(1, total);
  return shown / total;
}

/// 단어 뜻 채우기의 남은 횟수 안내. 숫자만 있으면 쓴 횟수인지 남은
/// 횟수인지 알 수 없어서 문장 추가 화면과 같은 말로 적는다(5차).
/// 단어를 아직 안 적어서 채울 수 없을 때(5차 474, 사용자가 헷갈렸다).
///
/// 단추가 흐린데 까닭이 없어서, 쓸 수 없는 기능인 줄 알았다. 문장 화면과
/// 같은 꼴로 말한다(5차 475).
final String wordFillNeedsWordHint = assistNeedsTextHint('단어');

/// 오늘 횟수를 다 썼는지(5차 473).
///
/// 다 썼으면 단추를 눌리지 않게 두고 까닭을 미리 보여 준다. 전에는 눌러
/// 보고서야 "다 썼어요"를 알았다.
/// 뜻·발음 채우기 단추 아래 설명(5차 472).
///
/// 뜻·발음과 예문은 쓰임이 다르다. 뜻·발음은 한 번 채우면 끝이고, 예문은
/// 여러 개를 더 받는다. 그래서 단추를 나누고 각자 제 자리에 둔다.
const String wordFillBasicsHint = '한 번만 채우면 돼요';

/// 예문 채우기 단추 아래 설명(5차 472).
const String wordFillExamplesHint = '겹치지 않는 예문을 받아요';

/// 뜻과 발음이 이미 다 차 있을 때(5차 525).
///
/// 고치기 시트는 이때 서버를 부르지 않고 돌아서는데, 까닭은 시트 맨 아래
/// _notice에만 적었다. 단추는 파랗게 켜진 채라, 눌러도 아무 일이 없는
/// 것처럼 보였다(506·515·519에서 고친 것과 같은 결함).
/// 문장 추가 화면도 같은 말을 쓴다(526).
const String wordFillBasicsDoneHint = assistBasicsDoneMessage;

String wordAssistUsageLabel({
  required int? used,
  required int? limit,
  bool failed = false,
}) {
  final label = assistUsageLabel(used: used, limit: limit);
  if (label != null) return label;
  // 서버가 횟수를 알려 주지 않으면 아무 말도 하지 않는다. 전에는 '확인
  // 중…'이 그대로 남아 고장난 것처럼 보였다.
  return failed ? '' : assistUsageLoadingLabel;
}

/// 복습 답 버튼 하나와 그 아래 '며칠 뒤에 다시 나오는지'.
class _RatingChoice extends StatelessWidget {
  const _RatingChoice({
    required this.label,
    required this.nextLabel,
    required this.onPressed,
    required this.child,
  });

  final String label;
  final String nextLabel;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      child,
      const SizedBox(height: 4),
      Text(
        nextLabel,
        key: ValueKey('review-next-$label'),
        style:
            context.texts.labelSmall.copyWith(color: colors.onSurfaceVariant),
      ),
    ]);
  }
}
