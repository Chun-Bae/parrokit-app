// 내 문장을 둘러보기에 공유하는 시트(5차 340, 사용자 요청).
//
// 전에는 문장 상세에 들어가거나 목록에서 밀어야만 공유할 수 있었다. 커뮤니티
// 문장 탭의 단추로 바로 고를 수 있게 한다. 묻는 말은 다른 곳과 같은 것을 쓴다
// (`sentence_share_text.dart`).

import 'package:parrokit/core/shared/utils/action_failed_text.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:parrokit/core/content/default_conversation_sentences.dart';
import 'package:parrokit/core/content/my_sentence_store.dart';
import 'package:parrokit/core/content/sentence_share_text.dart';
import 'package:parrokit/core/content/shared_sentence_repository.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/widgets/app_bottom_sheet.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';

/// 내 문장 공유 시트를 연다.
Future<void> showShareMySentenceSheet(
  BuildContext context, {
  SharedSentenceRepository? repository,
}) {
  final user = context.read<UserProvider?>()?.currentUser;
  return showAppSheet<void>(
    context: context,
    builder: (_) => ShareMySentenceSheet(
      accountId: user?.id ?? 'guest',
      authorName: user?.displayName ?? '',
      repository: repository,
    ),
  );
}

class ShareMySentenceSheet extends StatefulWidget {
  const ShareMySentenceSheet({
    super.key,
    required this.accountId,
    required this.authorName,
    this.repository,
  });

  final String accountId;
  final String authorName;

  /// 비우면 Firestore를 쓴다. 테스트에서 가짜를 넣는다.
  final SharedSentenceRepository? repository;

  @override
  State<ShareMySentenceSheet> createState() => _ShareMySentenceSheetState();
}

class _ShareMySentenceSheetState extends State<ShareMySentenceSheet> {
  /// 로그인하지 않았으면 공유할 수 없다(공유 문장은 서버에 올라간다).
  bool get _guest =>
      widget.accountId.trim().isEmpty || widget.accountId == 'guest';

  List<DefaultConversationSentence> mine = [];
  Set<String> published = {};
  bool loading = true;
  SharedSentenceRepository? _repository;
  String? working;

  SharedSentenceRepository? get repository {
    if (_repository != null) return _repository;
    try {
      return _repository =
          widget.repository ?? FirestoreSharedSentenceRepository();
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final sentences = await MySentenceStore.load(widget.accountId);
      final ids = await MySentenceStore.publishedIds(widget.accountId);
      if (!mounted) return;
      setState(() {
        mine = sentences.reversed.toList(growable: false);
        published = ids;
        loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  /// 알린 글. 시트 맨 위 안내 자리에 적는다(5차 369).
  ///
  /// 전에는 SnackBar로 알렸는데 이 화면은 바텀시트라 시트가 아래를 덮어
  /// 보이지 않았다(368에서 단어 시트로 확인).
  String? note;
  bool noteBad = false;

  void _say(String message, {bool bad = true}) {
    if (!mounted) return;
    setState(() {
      note = message;
      noteBad = bad;
    });
  }

  Future<void> _toggle(DefaultConversationSentence sentence) async {
    final repo = repository;
    if (repo == null) {
      _say('지금은 공유할 수 없어요. 잠시 뒤 다시 해 주세요.');
      return;
    }
    final isPublished = published.contains(sentence.id);
    if (!isPublished && widget.authorName.trim().isEmpty) {
      _say(sentenceShareNeedsNickname);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(sentenceShareTitle(published: isPublished)),
        content: Text(sentenceShareBody(
            published: isPublished, authorName: widget.authorName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(sentenceShareCancelLabel(published: isPublished)),
          ),
          FilledButton(
            key: const ValueKey('share-sentence-confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(sentenceShareConfirmLabel(published: isPublished)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => working = sentence.id);
    try {
      if (isPublished) {
        await repo.unpublish(sentenceId: sentence.id);
      } else {
        await repo.publish(
            sentenceId: sentence.id, authorName: widget.authorName);
      }
      if (!mounted) return;
      setState(() {
        working = null;
        if (isPublished) {
          published.remove(sentence.id);
        } else {
          published.add(sentence.id);
        }
      });
      _say(isPublished ? sentenceShareCanceledMessage : sentenceSharedMessage,
          bad: false);
    } on ShareLimitReachedException {
      if (!mounted) return;
      setState(() => working = null);
      _say(sentenceShareLimitMessage(SharedSentenceRepository.dailyShareLimit));
    } catch (_) {
      if (!mounted) return;
      setState(() => working = null);
      _say(actionFailedMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(shareMySentenceLabel,
                style: context.texts.titleLarge
                    .copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
                note ??
                    (_guest
                        ? sentenceShareNeedsLogin
                        : '고른 문장이 둘러보기에 올라가요. 언제든 다시 눌러 내릴 수 있어요.'),
                key: const ValueKey('share-sheet-note'),
                style: context.texts.bodySmall.copyWith(
                    color: note != null
                        ? (noteBad ? colors.error : colors.primary)
                        : (_guest ? colors.error : colors.onSurfaceVariant))),
            const SizedBox(height: 12),
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.55,
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : mine.isEmpty
                      ? Center(
                          child: Text('아직 내 문장이 없어요. 먼저 문장을 추가해 보세요.',
                              style: context.texts.bodyMedium
                                  .copyWith(color: colors.onSurfaceVariant)),
                        )
                      : ListView.separated(
                          itemCount: mine.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: colors.outlineVariant),
                          itemBuilder: (context, index) {
                            final sentence = mine[index];
                            final isPublished = published.contains(sentence.id);
                            final busy = working == sentence.id;
                            return ListTile(
                              key: ValueKey('share-pick-${sentence.id}'),
                              contentPadding: EdgeInsets.zero,
                              title: Text(sentence.text,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.texts.bodyLarge
                                      .copyWith(fontWeight: FontWeight.w700)),
                              // 둘러보기는 언어별로 보여 주므로 어떤 언어로
                              // 올라가는지 함께 적는다(5차 341).
                              subtitle: Text(
                                  '${sentence.language} · ${sentence.translation}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              trailing: busy
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : isPublished
                                      ? TextButton(
                                          onPressed: () => _toggle(sentence),
                                          child: const Text('공유 중'),
                                        )
                                      : FilledButton.tonal(
                                          // 게스트는 눌러도 안 되니 꺼 둔다.
                                          // 까닭은 위 줄에 적혀 있다(5차 346).
                                          onPressed: _guest
                                              ? null
                                              : () => _toggle(sentence),
                                          child: const Text('공유'),
                                        ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
