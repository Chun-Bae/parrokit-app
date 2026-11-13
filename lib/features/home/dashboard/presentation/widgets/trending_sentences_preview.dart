import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:parrokit/core/content/default_conversation_sentences.dart';
import 'package:parrokit/core/content/my_sentence_store.dart';
import 'package:parrokit/core/content/sentence_activity_store.dart';
import 'package:parrokit/core/content/shared_sentence_repository.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';

/// 홈의 "인기 공유 문장". 보관함 둘러보기에 공개된 문장 중 좋아요가 많은 것을 보여준다.
/// 전에는 코드에 박힌 예시 문장과 가짜 사용자·좋아요 수였다.
class TrendingSentencesPreview extends StatefulWidget {
  const TrendingSentencesPreview({
    super.key,
    required this.language,
    required this.onViewAll,
    this.onOpenLibrary,
    this.repository,
  });

  final String language;
  final VoidCallback onViewAll;

  /// 공유 문장이 없을 때 '보관함으로' 버튼. 내 문장을 공유하러 보관함 문장 탭으로
  /// 간다. 예전엔 비어 있는 둘러보기(onViewAll)를 열었다(5차). 비우면 onViewAll.
  final VoidCallback? onOpenLibrary;

  /// 공개 문장 저장소. 비우면 Firestore를 쓴다.
  final SharedSentenceRepository? repository;

  @override
  State<TrendingSentencesPreview> createState() =>
      _TrendingSentencesPreviewState();
}

class _TrendingSentencesPreviewState extends State<TrendingSentencesPreview> {
  static const _limit = 5;

  String? accountId;
  List<SharedSentence> items = [];
  List<DefaultConversationSentence> mine = [];
  bool loading = true;
  bool failed = false;
  SharedSentenceRepository? _repository;

  SharedSentenceRepository? get repository {
    if (_repository != null) return _repository;
    try {
      return _repository =
          widget.repository ?? FirestoreSharedSentenceRepository();
    } catch (_) {
      // Firebase가 준비되지 않았으면 섹션을 숨긴다.
      return null;
    }
  }

  bool get signedIn => accountId != null && accountId != 'guest';

  @override
  void initState() {
    super.initState();
    SharedSentenceRepository.revision.addListener(reloadQuietly);
    SentenceActivityStore.revision.addListener(reloadMine);
  }

  @override
  void dispose() {
    SharedSentenceRepository.revision.removeListener(reloadQuietly);
    SentenceActivityStore.revision.removeListener(reloadMine);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TrendingSentencesPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.language != widget.language && accountId != null) load();
  }

  void reloadQuietly() {
    if (accountId != null) load(silent: true);
  }

  Future<void> reloadMine() async {
    final requested = accountId;
    if (requested == null) return;
    try {
      final list = await MySentenceStore.load(requested);
      if (!mounted || requested != accountId) return;
      setState(() => mine = list);
    } catch (_) {/* 저장 표시만 못 바꾼다. */}
  }

  Future<void> load({bool silent = false}) async {
    final repo = repository;
    final requestedLanguage = widget.language;
    final requestedAccount = accountId!;
    if (repo == null) {
      setState(() {
        loading = false;
        failed = true;
      });
      return;
    }
    if (!silent) {
      setState(() {
        loading = true;
        failed = false;
      });
    }
    try {
      final list = await repo.popular(
        language: requestedLanguage,
        viewerId: signedIn ? requestedAccount : '',
        limit: _limit,
      );
      if (!mounted ||
          requestedLanguage != widget.language ||
          requestedAccount != accountId) {
        return;
      }
      setState(() {
        items = list;
        loading = false;
        failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      // 새로고침에 실패하면 보던 목록은 그대로 둔다.
      if (silent && items.isNotEmpty) return;
      setState(() {
        loading = false;
        failed = true;
      });
    }
  }

  void toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(message), duration: const Duration(seconds: 2)));
  }

  void replace(SharedSentence sentence, SharedSentence next) => setState(() {
        items = [
          for (final item in items)
            if (item.id == sentence.id) next else item,
        ];
      });

  /// 좋아요를 바로 반영하고, 저장에 실패하면 되돌린다.
  Future<void> toggleLike(SharedSentence sentence) async {
    final repo = repository;
    if (repo == null || !signedIn) {
      toast('로그인 후 좋아요를 누를 수 있어요.');
      return;
    }
    final liked = !sentence.liked;
    final next = sentence.copyWith(
      liked: liked,
      likeCount: sentence.likeCount + (liked ? 1 : -1),
    );
    replace(sentence, next);
    try {
      await repo.setLiked(
          sharedId: sentence.id, viewerId: accountId!, liked: liked);
    } catch (_) {
      if (!mounted) return;
      replace(next, sentence);
      toast('좋아요를 저장하지 못했어요. 다시 시도해주세요.');
    }
  }

  /// 이 공개 문장과 같은 내 문장. 보관함 둘러보기와 같은 기준으로 찾는다.
  DefaultConversationSentence? savedCopyOf(SharedSentence sentence) {
    for (final item in mine) {
      if (item.id == sentence.id ||
          item.sourceSharedId == sentence.id ||
          (item.language == sentence.language &&
              item.text.trim() == sentence.text.trim())) {
        return item;
      }
    }
    return null;
  }

  bool isMine(SharedSentence sentence) =>
      signedIn && sentence.authorId == accountId;

  /// 내 문장에 저장하거나 뺀다. 보관함 둘러보기의 저장 버튼과 같은 동작이다.
  Future<void> toggleSave(SharedSentence sentence) async {
    final account = accountId;
    if (account == null) return;
    final saved = savedCopyOf(sentence);
    try {
      if (saved != null) {
        if (isMine(sentence)) {
          toast('내가 올린 문장이에요. 지우려면 내 문장에서 삭제해주세요.');
          return;
        }
        await MySentenceStore.remove(account, saved.id);
        await reloadMine();
        if (mounted) toast('내 문장에서 뺐어요.');
        return;
      }
      final added = await MySentenceStore.add(
        account,
        language: sentence.language,
        text: sentence.text,
        translation: sentence.translation,
        pronunciation: sentence.pronunciation,
        topic: sentence.topic,
        author: sentence.authorName,
        authorId: sentence.authorId,
        sourceSharedId: sentence.id,
      );
      if (added) await countImport(sentence);
      await reloadMine();
      if (mounted) toast('내 문장에 저장했어요. 홈 앵무새가 말해줘요.');
    } catch (_) {
      if (mounted) toast('저장하지 못했어요. 다시 시도해주세요.');
    }
  }

  /// 가져간 사람 수를 올린다. 세지 못해도 저장은 그대로 둔다.
  Future<void> countImport(SharedSentence sentence) async {
    final repo = repository;
    if (repo == null || !signedIn || isMine(sentence)) return;
    try {
      final counted =
          await repo.recordImport(sharedId: sentence.id, viewerId: accountId!);
      if (!counted || !mounted) return;
      final current = items.where((item) => item.id == sentence.id);
      if (current.isEmpty) return;
      replace(current.first,
          current.first.copyWith(importCount: current.first.importCount + 1));
    } catch (_) {/* 가져간 수만 못 올린다. */}
  }

  @override
  Widget build(BuildContext context) {
    final currentAccount =
        context.watch<UserProvider?>()?.currentUser?.id ?? 'guest';
    if (currentAccount != accountId) {
      accountId = currentAccount;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || accountId != currentAccount) return;
        load();
        reloadMine();
      });
    }
    // Firebase가 없으면(테스트 등) 섹션 자체를 그리지 않는다.
    if (repository == null) return const SizedBox.shrink();

    final palette = HomeTokens.of(context);
    final ink = palette.ink;
    final muted = palette.muted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: palette.likeSoft,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite_rounded, size: 11, color: palette.like),
                  const SizedBox(width: 4),
                  Text(
                    '인기',
                    style: context.texts.labelSmall
                        .copyWith(color: palette.likeInk),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Flexible + Spacer는 남는 칸을 반씩 나눠 '전체 보기'가 오른쪽 끝에
            // 붙지 않았다(위 '내 문장 기록'과 어긋남, 5차). 제목이 남는 칸을 다 쓴다.
            Expanded(
              child: Text(
                '공유 문장',
                overflow: TextOverflow.ellipsis,
                style: context.texts.headlineSmall
                    .copyWith(color: ink, letterSpacing: -0.4),
              ),
            ),
            TextButton(
              onPressed: widget.onViewAll,
              // 바로 위 "내 문장 기록"의 '전체 보기'와 같은 말, 같은 색으로 맞춘다.
              child: Text('전체 보기', style: TextStyle(color: muted)),
            ),
          ],
        ),
        // "다른 사람들이 공유한 문장을 좋아요 순으로 보여줘요" 부제는 제목 옆
        // '인기' 표시와 같은 말이라 지웠다.
        const SizedBox(height: 12),
        if (loading)
          SizedBox(
            height: 120,
            child: Center(
              child: SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: palette.primary),
              ),
            ),
          )
        else if (failed)
          _NoticeCard(
            icon: Icons.cloud_off_rounded,
            title: '공유된 문장을 불러오지 못했어요',
            actionLabel: '다시 시도',
            onAction: load,
          )
        else if (items.isEmpty)
          _NoticeCard(
            icon: Icons.ios_share_rounded,
            title: '아직 공유된 ${widget.language} 문장이 없어요',
            body: '보관함에서 내 문장을 공유하면 여기에 나와요.',
            actionLabel: '보관함으로',
            onAction: widget.onOpenLibrary ?? widget.onViewAll,
          )
        else
          SizedBox(
            height: 196,
            child: ListView.separated(
              clipBehavior: Clip.none,
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                return _SentenceCard(
                  item: item,
                  saved: savedCopyOf(item) != null,
                  onLike: () => toggleLike(item),
                  onSave: () => toggleSave(item),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// 비어 있거나 불러오지 못했을 때 카드 자리를 채운다.
class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.title,
    required this.actionLabel,
    required this.onAction,
    this.body,
  });

  final IconData icon;
  final String title;
  final String? body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final palette = HomeTokens.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: palette.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: context.texts.titleMedium
                        .copyWith(color: palette.ink)),
                if (body != null) ...[
                  const SizedBox(height: 2),
                  Text(body!,
                      style: context.texts.bodySmall
                          .copyWith(color: palette.muted)),
                ],
              ],
            ),
          ),
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel,
                style: TextStyle(color: palette.primary)),
          ),
        ],
      ),
    );
  }
}

class _SentenceCard extends StatelessWidget {
  const _SentenceCard({
    required this.item,
    required this.saved,
    required this.onLike,
    required this.onSave,
  });

  final SharedSentence item;
  final bool saved;
  final VoidCallback onLike;
  final VoidCallback onSave;

  /// 공유한 시각을 "방금·n분 전·n시간 전·n일 전·M월 d일"로 줄인다.
  static String ageOf(DateTime? at, DateTime now) {
    if (at == null) return '방금';
    final diff = now.difference(at);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${at.month}월 ${at.day}일';
  }

  @override
  Widget build(BuildContext context) {
    final palette = HomeTokens.of(context);
    final ink = palette.ink;
    final muted = palette.muted;
    final author = item.authorName.trim().isEmpty ? '익명' : item.authorName;

    return Container(
      width: 284,
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 9),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: palette.shadow.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: palette.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  child: Text(
                    item.topic,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.labelSmall
                        .copyWith(color: palette.inkSoft),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(ageOf(item.createdAt, DateTime.now()),
                  style: context.texts.labelSmall.copyWith(color: muted)),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            item.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.texts.titleLarge.copyWith(color: ink, height: 1.25),
          ),
          const SizedBox(height: 5),
          Text(
            item.translation,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.texts.bodySmall.copyWith(color: muted),
          ),
          const Spacer(),
          Row(
            children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: palette.primary.withValues(alpha: 0.12),
                child:
                    Icon(Icons.person_rounded, size: 14, color: palette.primary),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.labelSmall.copyWith(color: muted)),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: '좋아요',
                onPressed: onLike,
                icon: Icon(
                  item.liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 20,
                  color: item.liked ? palette.like : muted,
                ),
              ),
              Text('${item.likeCount}',
                  style: context.texts.labelSmall.copyWith(color: muted)),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: saved ? '내 문장에서 빼기' : '내 문장에 저장',
                onPressed: onSave,
                icon: Icon(
                  saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  size: 20,
                  color: saved ? palette.primary : muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
