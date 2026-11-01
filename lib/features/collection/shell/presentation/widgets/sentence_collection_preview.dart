import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:parrokit/core/content/default_conversation_sentences.dart';
import 'package:parrokit/core/content/my_sentence_store.dart';
import 'package:parrokit/core/content/sentence_mastery.dart';
import 'package:parrokit/core/content/sentence_activity_store.dart';
import 'package:parrokit/core/content/shared_sentence_repository.dart';
import 'package:parrokit/core/shared/widgets/learning_language_picker.dart';
import 'clip_sentence_matches_section.dart';
import 'package:parrokit/features/home/dashboard/presentation/add_sentence_screen.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class SentenceCollectionPreview extends StatefulWidget {
  const SentenceCollectionPreview({super.key, this.repository});

  /// 둘러보기 공개 문장 저장소. 비우면 Firestore를 쓴다.
  final SharedSentenceRepository? repository;

  @override
  State<SentenceCollectionPreview> createState() =>
      _SentenceCollectionPreviewState();
}

class _SentenceCollectionPreviewState extends State<SentenceCollectionPreview> {
  bool explore = true;
  String language = '영어';
  String category = '전체';
  String accountId = 'guest';
  bool loadedOnce = false;
  List<DefaultConversationSentence> mine = [];
  Map<String, SentenceActivity> activities = {};
  String authorName = '';

  /// 둘러보기에 공개된 문장.
  List<SharedSentence> shared = [];
  bool sharedLoading = true;
  bool sharedFailed = false;
  SharedSentenceRepository? _repository;

  SharedSentenceRepository? get repository {
    if (_repository != null) return _repository;
    try {
      return _repository =
          widget.repository ?? FirestoreSharedSentenceRepository();
    } catch (_) {
      // Firebase가 준비되지 않았으면 둘러보기는 비어 있는 채로 둔다.
      return null;
    }
  }

  static const categories = ['전체', '일상', '여행', '카페', '감정', '회사', '학교'];
  static const packs = [
    _SentencePack('카페에서 바로 쓰는 말', '8문장 · 입문', Icons.local_cafe_rounded,
        Color(0xFFFFE8C7)),
    _SentencePack(
        '짧은 일상 반응', '12문장 · 초급', Icons.chat_bubble_rounded, Color(0xFFDDEFEA)),
    _SentencePack(
        '여행 첫날 표현', '10문장 · 초급', Icons.luggage_rounded, Color(0xFFDCE9F8)),
  ];
  @override
  void initState() {
    super.initState();
    SentenceActivityStore.revision.addListener(reload);
  }

  @override
  void dispose() {
    SentenceActivityStore.revision.removeListener(reload);
    super.dispose();
  }

  Future<void> reload() async {
    final requested = accountId;
    try {
      final results = await Future.wait([
        MySentenceStore.load(requested),
        SentenceActivityStore.loadAll(requested),
      ]);
      if (!mounted || requested != accountId) return;
      setState(() {
        mine = results[0] as List<DefaultConversationSentence>;
        activities = results[1] as Map<String, SentenceActivity>;
      });
    } catch (_) {
      // 읽지 못하면 기본 문장만 보여준다.
    }
  }

  Future<void> loadShared() async {
    final repo = repository;
    final requestedLanguage = language;
    final requestedAccount = accountId;
    if (repo == null) {
      setState(() {
        sharedLoading = false;
        sharedFailed = true;
      });
      return;
    }
    setState(() {
      sharedLoading = true;
      sharedFailed = false;
    });
    try {
      final list = await repo.list(
        language: requestedLanguage,
        viewerId: requestedAccount == 'guest' ? '' : requestedAccount,
      );
      if (!mounted ||
          requestedLanguage != language ||
          requestedAccount != accountId) {
        return;
      }
      setState(() {
        shared = list;
        sharedLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        sharedLoading = false;
        sharedFailed = true;
      });
    }
  }

  /// 둘러보기 문장의 좋아요를 바로 반영하고, 저장에 실패하면 되돌린 뒤 예외를 던진다.
  Future<void> setSharedLiked(SharedSentence sentence, bool liked) async {
    final repo = repository;
    if (repo == null || accountId == 'guest') {
      toast('로그인 후 좋아요를 누를 수 있어요.');
      throw StateError('not signed in');
    }
    void apply(bool value) => setState(() {
          shared = [
            for (final item in shared)
              if (item.id == sentence.id)
                item.copyWith(
                  liked: value,
                  likeCount: item.likeCount +
                      (value == item.liked ? 0 : (value ? 1 : -1)),
                )
              else
                item,
          ];
        });
    apply(liked);
    try {
      await repo.setLiked(
          sharedId: sentence.id, viewerId: accountId, liked: liked);
    } catch (_) {
      if (mounted) {
        apply(!liked);
        toast('좋아요를 저장하지 못했어요. 다시 시도해주세요.');
      }
      rethrow;
    }
  }

  void toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String communityId(SharedSentence sentence) =>
      MySentenceStore.idFor(sentence.language, sentence.text);

  bool isSaved(SharedSentence sentence) =>
      mine.any((item) => item.id == communityId(sentence));

  bool isParrotActive(SharedSentence sentence) =>
      isSaved(sentence) &&
      (activities[communityId(sentence)]?.routineEnabled ?? true);

  Future<void> toggleSave(SharedSentence sentence) async {
    try {
      if (isSaved(sentence)) {
        await MySentenceStore.remove(accountId, communityId(sentence));
        if (mounted) toast('내 문장에서 뺐어요.');
      } else {
        await MySentenceStore.add(
          accountId,
          language: sentence.language,
          text: sentence.text,
          translation: sentence.translation,
          topic: sentence.topic,
          author: sentence.authorName,
        );
        if (mounted) toast('내 문장에 저장했어요. 홈 앵무새가 말해줘요.');
      }
    } catch (_) {
      if (mounted) toast('저장하지 못했어요. 다시 시도해주세요.');
    }
  }

  /// 둘러보기 문장의 상세. 아직 저장하지 않았어도 열 수 있다.
  Future<void> openCommunityDetails(SharedSentence sentence) =>
      showSentenceDetails(
        context,
        accountId: accountId,
        saved: isSaved(sentence),
        repository: repository,
        authorName: authorName,
        shared: sentence,
        onSharedLike: (liked) => setSharedLiked(sentence, liked),
        sentence: DefaultConversationSentence(
          id: communityId(sentence),
          language: sentence.language,
          text: sentence.text,
          translation: sentence.translation,
          pronunciation: sentence.pronunciation,
          topic: sentence.topic,
          author: sentence.authorName,
        ),
      );

  Future<void> toggleParrot(SharedSentence sentence) async {
    try {
      final id = communityId(sentence);
      if (!isSaved(sentence)) {
        await MySentenceStore.add(
          accountId,
          language: sentence.language,
          text: sentence.text,
          translation: sentence.translation,
          pronunciation: sentence.pronunciation,
          topic: sentence.topic,
          author: sentence.authorName,
        );
        await SentenceActivityStore.setRoutineEnabled(accountId, id, true);
        if (mounted) toast('앵무새에게 보냈어요.');
        return;
      }
      final next = !isParrotActive(sentence);
      await SentenceActivityStore.setRoutineEnabled(accountId, id, next);
      if (mounted) toast(next ? '앵무새가 다시 말해줘요.' : '앵무새 루틴에서 뺐어요.');
    } catch (_) {
      if (mounted) toast('설정을 저장하지 못했어요. 다시 시도해주세요.');
    }
  }

  Future<void> addMySentence() async {
    try {
      final result = await addSentenceFlow(
        context,
        accountId: accountId,
        language: language,
      );
      if (!mounted || result == null) return;
      toast(result.added ? '추가했어요. 홈 앵무새가 말해줘요.' : '이미 있는 문장이에요.');
    } catch (_) {
      if (mounted) toast('문장을 저장하지 못했어요. 다시 시도해주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final currentAccountId =
        context.watch<UserProvider?>()?.currentUser?.id ?? 'guest';
    authorName = context.watch<UserProvider?>()?.currentUser?.displayName ?? '';
    if (!loadedOnce || currentAccountId != accountId) {
      loadedOnce = true;
      accountId = currentAccountId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        reload();
        loadShared();
      });
    }
    final basicSentences = defaultSentencesFor(language);
    // 최근에 추가한 문장이 맨 위에 오도록 뒤집고, 기본 문장은 그 아래에 둔다.
    final mySentences = [
      ...mine.where((item) => item.language == language).toList().reversed,
      ...basicSentences,
    ];
    final visibleShared = category == '전체'
        ? shared
        : shared.where((item) => item.topic == category).toList();
    final routineCount = mySentences
        .where((item) => activities[item.id]?.routineEnabled ?? true)
        .length;
    return ListView(
      key: const PageStorageKey('sentence-collection-preview'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 140),
      children: [
        _ViewSwitch(
            explore: explore,
            onChanged: (value) => setState(() => explore = value)),
        const SizedBox(height: 16),
        LearningLanguagePicker(
          value: language,
          onChanged: (value) {
            setState(() => language = value);
            loadShared();
          },
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 7),
            itemBuilder: (context, index) {
              final item = categories[index];
              return ChoiceChip(
                  label: Text(item),
                  selected: category == item,
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => setState(() => category = item));
            },
          ),
        ),
        const SizedBox(height: 24),
        if (explore) ...[
          _SectionTitle(
              title: 'Parrokit 제공',
              subtitle: '계속 추가되는 문장 묶음',
              trailing: TextButton(onPressed: () {}, child: const Text('전체'))),
          const SizedBox(height: 10),
          SizedBox(
            height: 148,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: packs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) => _PackCard(pack: packs[index]),
            ),
          ),
          const SizedBox(height: 28),
          _SectionTitle(title: '공유된 문장', subtitle: '다른 사람이 공유한 문장을 저장해서 연습해요'),
          const SizedBox(height: 10),
          if (sharedLoading)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()))
          else if (sharedFailed)
            _SharedMessage(
                key: const ValueKey('shared-message'),
                text: '공유된 문장을 불러오지 못했어요.',
                actionLabel: '다시 불러오기',
                onAction: loadShared)
          else if (visibleShared.isEmpty)
            const _SharedMessage(
                key: ValueKey('shared-message'),
                text: '아직 공유된 문장이 없어요. 내 문장을 공유해 보세요.')
          else
            ...visibleShared.map((sentence) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SentenceCard(
                    sentence: sentence,
                    saved: isSaved(sentence),
                    active: isParrotActive(sentence),
                    onLike: () => unawaited(
                        setSharedLiked(sentence, !sentence.liked)
                            .catchError((Object _) {})),
                    onSave: () => toggleSave(sentence),
                    onParrot: () => toggleParrot(sentence),
                    onOpen: () => openCommunityDetails(sentence),
                  ),
                )),
        ] else ...[
          _SectionTitle(
              title: '앵무새가 말할 문장',
              subtitle: '지금 활성화된 문장을 빠르게 연습해요',
              trailing: IconButton.filledTonal(
                  tooltip: '문장 추가',
                  onPressed: addMySentence,
                  icon: const Icon(Icons.add_rounded))),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.record_voice_over_rounded)),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('앵무새가 말할 문장 $routineCount개',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Text('홈 앵무새가 순서대로 말해줘요',
                        style: TextStyle(fontSize: 12)),
                  ])),
            ]),
          ),
          const SizedBox(height: 24),
          const _SectionTitle(title: '내 문장', subtitle: '최근 추가한 순서'),
          const SizedBox(height: 10),
          ...List.generate(mySentences.length, (index) {
            final sentence = mySentences[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MySentenceTile(
                sentence: sentence,
                accountId: accountId,
                activity: activities[sentence.id] ?? const SentenceActivity(),
                repository: repository,
                authorName: authorName,
              ),
            );
          }),
        ],
      ],
    );
  }
}

class _ViewSwitch extends StatelessWidget {
  const _ViewSwitch({required this.explore, required this.onChanged});

  final bool explore;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(15)),
        child: Row(children: [
          Expanded(
              child: _SwitchItem(
                  label: '내 문장',
                  selected: !explore,
                  onTap: () => onChanged(false))),
          Expanded(
              child: _SwitchItem(
                  label: '둘러보기',
                  selected: explore,
                  onTap: () => onChanged(true))),
        ]),
      );
}

class _SwitchItem extends StatelessWidget {
  const _SwitchItem(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected
            ? Theme.of(context).colorScheme.surface
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: selected
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)))),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(
      {required this.title, required this.subtitle, this.trailing});

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(subtitle,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12)),
        ])),
        if (trailing != null) trailing!,
      ]);
}

class _PackCard extends StatelessWidget {
  const _PackCard({required this.pack});

  final _SentencePack pack;

  @override
  Widget build(BuildContext context) => Container(
        width: 174,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: pack.color, borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(20)),
                child: const Text('공식',
                    style:
                        TextStyle(fontSize: 10, fontWeight: FontWeight.w800))),
            Icon(pack.icon, size: 23, color: const Color(0xFF3D5966)),
          ]),
          const Spacer(),
          Text(pack.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(pack.detail,
              style: const TextStyle(fontSize: 11, color: Color(0xFF526977))),
        ]),
      );
}

class _SentenceCard extends StatelessWidget {
  const _SentenceCard({
    required this.sentence,
    required this.saved,
    required this.active,
    required this.onLike,
    required this.onSave,
    required this.onParrot,
    required this.onOpen,
  });

  final SharedSentence sentence;
  final bool saved;
  final bool active;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onParrot;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 8),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .secondaryContainer
                            .withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(sentence.topic,
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w800))),
                const Spacer(),
                Text('@${sentence.authorName}',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 11)),
              ]),
              const SizedBox(height: 12),
              Text(sentence.text,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text(sentence.translation,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13)),
              const SizedBox(height: 8),
              Row(children: [
                IconButton(
                    tooltip: '좋아요',
                    visualDensity: VisualDensity.compact,
                    onPressed: onLike,
                    icon: Icon(
                        sentence.liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border,
                        color:
                            sentence.liked ? const Color(0xFFFF768B) : null)),
                Text('${sentence.likeCount}',
                    style: const TextStyle(fontSize: 12)),
                const Spacer(),
                IconButton(
                    tooltip: '내 문장에 저장',
                    visualDensity: VisualDensity.compact,
                    onPressed: onSave,
                    icon: Icon(saved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded)),
                IconButton(
                    tooltip: '앵무새에게 보내기',
                    visualDensity: VisualDensity.compact,
                    onPressed: onParrot,
                    icon: Icon(Icons.record_voice_over_rounded,
                        color: active ? const Color(0xFF6D9890) : null)),
              ]),
            ]),
          ),
        ),
      );
}

/// 문장 상세 시트를 하단 네비바까지 덮도록 루트 네비게이터에 띄운다.
/// [saved]가 false면 아직 내 문장이 아니라서 루틴·삭제 항목을 숨긴다.
Future<void> showSentenceDetails(
  BuildContext context, {
  required DefaultConversationSentence sentence,
  required String accountId,
  bool saved = true,
  SharedSentenceRepository? repository,
  String authorName = '',
  SharedSentence? shared,
  Future<void> Function(bool liked)? onSharedLike,
}) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _SentenceDetailSheet(
        sentence: sentence,
        accountId: accountId,
        saved: saved,
        repository: repository,
        authorName: authorName,
        shared: shared,
        onSharedLike: onSharedLike,
      ),
    );

class _MySentenceTile extends StatelessWidget {
  const _MySentenceTile({
    required this.sentence,
    required this.accountId,
    required this.activity,
    required this.repository,
    required this.authorName,
  });

  final DefaultConversationSentence sentence;
  final String accountId;
  final SentenceActivity activity;
  final SharedSentenceRepository? repository;
  final String authorName;

  Future<void> openDetails(BuildContext context) => showSentenceDetails(
        context,
        sentence: sentence,
        accountId: accountId,
        repository: repository,
        authorName: authorName,
      );

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(17),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: () => openDetails(context),
          title: Text(
            sentence.text,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(sentence.translation, maxLines: 1),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MasteryBadge(mastery: masteryOf(activity)),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      );
}

class _SentenceDetailSheet extends StatefulWidget {
  const _SentenceDetailSheet({
    required this.sentence,
    required this.accountId,
    this.saved = true,
    this.repository,
    this.authorName = '',
    this.shared,
    this.onSharedLike,
  });

  final DefaultConversationSentence sentence;
  final String accountId;
  final bool saved;

  /// 둘러보기 공유 저장소. 내 문장을 공개하거나 공개 취소할 때 쓴다.
  final SharedSentenceRepository? repository;

  /// 내 닉네임. 공유하면 작성자로 표시된다.
  final String authorName;

  /// 둘러보기에서 연 공개 문장이면 그 정보. 좋아요는 서버에 저장한다.
  final SharedSentence? shared;
  final Future<void> Function(bool liked)? onSharedLike;

  @override
  State<_SentenceDetailSheet> createState() => _SentenceDetailSheetState();
}

class _SentenceDetailSheetState extends State<_SentenceDetailSheet> {
  SentenceActivity activity = const SentenceActivity();
  bool loading = true;
  bool changingRoutine = false;

  /// 이 문장이 둘러보기에 공개돼 있는지. 모르면 null.
  bool? published;
  bool publishing = false;
  late bool sharedLiked = widget.shared?.liked ?? false;
  late int sharedLikes = widget.shared?.likeCount ?? 0;

  static const _ttsLocales = {'영어': 'en-US', '일본어': 'ja-JP', '중국어': 'zh-CN'};
  final FlutterTts tts = FlutterTts();
  bool ttsReady = false;
  bool speaking = false;

  @override
  void initState() {
    super.initState();
    loadActivity();
    unawaited(setupTts());
    unawaited(loadPublished());
  }

  /// 내가 등록한 문장만 공유할 수 있다. 기본 문장이나 남이 올린 문장은 해당이 없다.
  bool get canPublish =>
      widget.saved && widget.shared == null && publishBlockedReason == null;

  /// 공유할 수 없는 문장이면 그 이유. 공유할 수 있으면 null.
  String? get publishBlockedReason {
    if (widget.repository == null) return '지금은 공유 기능을 쓸 수 없어요.';
    if (!widget.sentence.id.startsWith('my-')) {
      return '기본 문장은 공유할 수 없어요. 내가 등록한 문장만 공유할 수 있어요.';
    }
    if (widget.sentence.author.isNotEmpty &&
        widget.sentence.author != widget.authorName) {
      return '다른 사람이 만든 문장은 공유할 수 없어요.';
    }
    return null;
  }

  Future<void> loadPublished() async {
    final repo = widget.repository;
    if (!canPublish || repo == null || widget.accountId == 'guest') return;
    try {
      final value = await repo.isPublished(
        authorId: widget.accountId,
        localSentenceId: widget.sentence.id,
      );
      if (mounted) setState(() => published = value);
    } catch (_) {/* 공개 여부를 모르면 버튼은 공유하기로 둔다. */}
  }

  /// 둘러보기에 공유하거나 공유를 취소한다.
  Future<void> togglePublish() async {
    final repo = widget.repository;
    if (repo == null || publishing) return;
    final messenger = ScaffoldMessenger.of(context);
    if (widget.accountId == 'guest') {
      messenger.showSnackBar(const SnackBar(content: Text('로그인 후 공유할 수 있어요.')));
      return;
    }
    if (published != true) {
      if (widget.authorName.trim().isEmpty) {
        messenger
            .showSnackBar(const SnackBar(content: Text('닉네임을 먼저 설정해주세요.')));
        return;
      }
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('둘러보기에 공유할까요?'),
          content: Text('모든 사용자에게 공개되고, 작성자로 "${widget.authorName}"이(가) 표시돼요. '
              '언제든 공유를 취소할 수 있어요.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('공유')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => publishing = true);
    try {
      if (published == true) {
        await repo.unpublish(
          authorId: widget.accountId,
          localSentenceId: widget.sentence.id,
        );
      } else {
        await repo.publish(
          localSentenceId: widget.sentence.id,
          authorId: widget.accountId,
          authorName: widget.authorName,
          language: widget.sentence.language,
          text: widget.sentence.text,
          translation: widget.sentence.translation,
          pronunciation: widget.sentence.pronunciation,
          topic: widget.sentence.topic,
        );
      }
      final next = published != true;
      if (mounted) setState(() => published = next);
      messenger.showSnackBar(
          SnackBar(content: Text(next ? '둘러보기에 공유했어요.' : '공유를 취소했어요.')));
    } catch (_) {
      messenger
          .showSnackBar(const SnackBar(content: Text('처리하지 못했어요. 다시 시도해주세요.')));
    } finally {
      if (mounted) setState(() => publishing = false);
    }
  }

  Future<void> setupTts() async {
    try {
      tts.setStartHandler(() => _setSpeaking(true));
      tts.setCompletionHandler(() => _setSpeaking(false));
      tts.setCancelHandler(() => _setSpeaking(false));
      tts.setErrorHandler((_) => _setSpeaking(false));
      await tts.setSpeechRate(0.45);
      ttsReady = true;
    } catch (_) {/* 음성을 쓸 수 없으면 소리만 나지 않는다. */}
  }

  void _setSpeaking(bool value) {
    if (mounted) setState(() => speaking = value);
  }

  /// 마이크 버튼: 이 문장을 TTS로 읽어준다. 읽는 중에 다시 누르면 멈춘다.
  Future<void> speakSentence() async {
    if (!ttsReady) return;
    try {
      if (speaking) {
        await tts.stop();
        return;
      }
      final locale = _ttsLocales[widget.sentence.language] ?? 'en-US';
      if (await tts.isLanguageAvailable(locale) != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('이 언어의 음성이 기기에 없어요.')),
          );
        }
        return;
      }
      await tts.setLanguage(locale);
      await tts.speak(widget.sentence.text);
    } catch (_) {
      _setSpeaking(false);
    }
  }

  @override
  void dispose() {
    unawaited(tts.stop());
    super.dispose();
  }

  Future<void> loadActivity() async {
    final loaded = await SentenceActivityStore.load(
      widget.accountId,
      widget.sentence.id,
    );
    if (!mounted) return;
    setState(() {
      activity = loaded;
      loading = false;
    });
  }

  Future<void> changeRoutine(bool enabled) async {
    if (changingRoutine) return;
    final before = activity;
    setState(() {
      changingRoutine = true;
      activity = activity.copyWith(routineEnabled: enabled);
    });
    try {
      await SentenceActivityStore.setRoutineEnabled(
        widget.accountId,
        widget.sentence.id,
        enabled,
      );
    } catch (_) {
      if (mounted) {
        setState(() => activity = before);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('루틴 설정을 저장하지 못했어요.')),
        );
      }
    } finally {
      if (mounted) setState(() => changingRoutine = false);
    }
  }

  Future<void> removeSentence() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await MySentenceStore.remove(widget.accountId, widget.sentence.id);
      navigator.pop();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('삭제하지 못했어요. 다시 시도해주세요.')),
      );
    }
  }

  /// 좋아요를 바로 반영하고, 저장에 실패하면 되돌린다.
  Future<void> toggleLike() async {
    final onShared = widget.onSharedLike;
    if (widget.shared != null && onShared != null) {
      final next = !sharedLiked;
      setState(() {
        sharedLiked = next;
        sharedLikes += next ? 1 : -1;
      });
      try {
        await onShared(next);
      } catch (_) {
        if (mounted) {
          setState(() {
            sharedLiked = !next;
            sharedLikes += next ? -1 : 1;
          });
        }
      }
      return;
    }
    final before = activity;
    final next = !activity.liked;
    setState(() => activity = activity.copyWith(liked: next));
    try {
      await SentenceActivityStore.setLiked(
        widget.accountId,
        widget.sentence.id,
        next,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => activity = before);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('좋아요를 저장하지 못했어요. 다시 시도해주세요.')),
      );
    }
  }

  Future<void> shareSentence() async {
    final renderBox = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        title: 'Parrokit 문장',
        subject: widget.sentence.text,
        text: '${widget.sentence.text}\n'
            '${widget.sentence.translation}\n'
            '${widget.sentence.pronunciation}\n'
            '${widget.sentence.author.isEmpty ? '' : 'by ${widget.sentence.author}\n'}'
            '\nParrokit에서 함께 연습해요.',
        sharePositionOrigin: renderBox == null
            ? null
            : renderBox.localToGlobal(Offset.zero) & renderBox.size,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final liked = widget.shared != null ? sharedLiked : activity.liked;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.paddingOf(context).bottom + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${widget.sentence.language} · ${widget.sentence.topic}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _MasteryBadge(mastery: masteryOf(activity)),
              const Spacer(),
              IconButton(
                key: const ValueKey('like-sentence'),
                tooltip: liked ? '좋아요 취소' : '좋아요',
                onPressed: loading && widget.shared == null ? null : toggleLike,
                icon: Icon(
                  liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: liked ? const Color(0xFFFF768B) : null,
                ),
              ),
              if (widget.shared != null)
                Text('$sharedLikes', style: const TextStyle(fontSize: 12)),
              IconButton(
                tooltip: '문장 공유',
                onPressed: shareSentence,
                icon: const Icon(Icons.ios_share_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  widget.sentence.text,
                  style: const TextStyle(
                    fontSize: 26,
                    height: 1.25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: speaking ? '듣기 멈추기' : '문장 듣기',
                onPressed: speakSentence,
                isSelected: speaking,
                icon: const Icon(Icons.mic_rounded),
                selectedIcon: const Icon(Icons.graphic_eq_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.sentence.pronunciation,
            style: TextStyle(
              color: colors.primary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            widget.sentence.translation,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 15,
            ),
          ),
          if (widget.sentence.author.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              key: const ValueKey('sentence-author'),
              children: [
                Icon(Icons.person_rounded,
                    size: 16, color: colors.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  widget.sentence.author,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(
                child: _ActivityCountCard(
                  icon: Icons.headphones_rounded,
                  label: '내가 들음',
                  count: activity.listenCount,
                  loading: loading,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActivityCountCard(
                  icon: Icons.mic_rounded,
                  label: '내가 연습함',
                  count: activity.practiceCount,
                  loading: loading,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _HistoryLine(
            icon: Icons.history_rounded,
            text: activity.lastPracticedAt == null
                ? '아직 따라 말해보지 않았어요'
                : '마지막 연습 ${relativeDayLabel(DateTime.now(), activity.lastPracticedAt!)}',
          ),
          if (widget.sentence.addedAt != null)
            _HistoryLine(
              icon: Icons.bookmark_added_outlined,
              text:
                  '${relativeDayLabel(DateTime.now(), widget.sentence.addedAt!)} 추가',
            ),
          const SizedBox(height: 14),
          ClipSentenceMatchesSection(sentence: widget.sentence.text),
          const SizedBox(height: 10),
          if (widget.saved)
            SwitchListTile(
              value: activity.routineEnabled,
              onChanged: loading || changingRoutine ? null : changeRoutine,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              secondary: const Icon(Icons.repeat_rounded),
              title: const Text(
                '홈 말하기 루틴',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                activity.routineEnabled
                    ? '앵무새가 홈에서 이 문장을 말해요.'
                    : '홈의 자동·따라 말하기 순환에서 제외돼요.',
              ),
            ),
          if (widget.saved && widget.sentence.id.startsWith('my-')) ...[
            TextButton.icon(
              onPressed: removeSentence,
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('내 문장에서 삭제'),
            ),
          ],
          const SizedBox(height: 10),
          if (widget.saved && widget.shared == null && !canPublish) ...[
            FilledButton.icon(
              key: const ValueKey('publish-sentence-disabled'),
              onPressed: null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              icon: const Icon(Icons.public_off_rounded),
              label: const Text('둘러보기에 공유하기'),
            ),
            const SizedBox(height: 6),
            Text(
              publishBlockedReason ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
          ],
          if (canPublish)
            FilledButton.icon(
              key: const ValueKey('publish-sentence'),
              onPressed: publishing ? null : togglePublish,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              icon: Icon(published == true
                  ? Icons.public_off_rounded
                  : Icons.public_rounded),
              label: Text(published == true ? '둘러보기 공유 취소' : '둘러보기에 공유하기'),
            ),
        ],
      ),
    );
  }
}

class _ActivityCountCard extends StatelessWidget {
  const _ActivityCountCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.loading,
  });

  final IconData icon;
  final String label;
  final int count;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colors.primary),
          const SizedBox(height: 12),
          Text(
            loading ? '—' : '$count번',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _SentencePack {
  const _SentencePack(this.title, this.detail, this.icon, this.color);
  final String title;
  final String detail;
  final IconData icon;
  final Color color;
}

class _SharedMessage extends StatelessWidget {
  const _SharedMessage({
    super.key,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(children: [
          Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          if (onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel ?? '')),
        ]),
      );
}

class _MasteryBadge extends StatelessWidget {
  const _MasteryBadge({required this.mastery});

  final SentenceMastery mastery;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (background, foreground) = switch (mastery) {
      SentenceMastery.fresh => (
          colors.surfaceContainerHighest,
          colors.onSurfaceVariant
        ),
      SentenceMastery.learning => (
          colors.tertiaryContainer,
          colors.onTertiaryContainer
        ),
      SentenceMastery.familiar => (
          colors.primaryContainer,
          colors.onPrimaryContainer
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        mastery.label,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _HistoryLine extends StatelessWidget {
  const _HistoryLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 7),
        Text(text, style: TextStyle(color: color, fontSize: 12)),
      ]),
    );
  }
}
