import 'package:flutter/material.dart';
import 'package:parrokit/core/content/default_conversation_sentences.dart';
import 'package:parrokit/core/content/my_sentence_store.dart';
import 'package:parrokit/core/content/sentence_activity_store.dart';
import 'package:parrokit/core/shared/widgets/learning_language_picker.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class SentenceCollectionPreview extends StatefulWidget {
  const SentenceCollectionPreview({super.key});

  @override
  State<SentenceCollectionPreview> createState() =>
      _SentenceCollectionPreviewState();
}

class _SentenceCollectionPreviewState extends State<SentenceCollectionPreview> {
  bool explore = true;
  String language = '영어';
  String category = '전체';
  final liked = <int>{1};
  String accountId = 'guest';
  bool loadedOnce = false;
  List<DefaultConversationSentence> mine = [];
  Map<String, SentenceActivity> activities = {};

  static const categories = ['전체', '일상', '여행', '카페', '감정', '회사', '학교'];
  static const packs = [
    _SentencePack('카페에서 바로 쓰는 말', '8문장 · 입문', Icons.local_cafe_rounded,
        Color(0xFFFFE8C7)),
    _SentencePack(
        '짧은 일상 반응', '12문장 · 초급', Icons.chat_bubble_rounded, Color(0xFFDDEFEA)),
    _SentencePack(
        '여행 첫날 표현', '10문장 · 초급', Icons.luggage_rounded, Color(0xFFDCE9F8)),
  ];
  static const communitySentences = [
    _SharedSentence(
        'Could I get this to go?', '이거 포장해 주실 수 있나요?', '카페', 'Mina', 128),
    _SharedSentence(
        'That made my day.', '덕분에 오늘 기분이 좋아졌어.', '감정', 'dailybird', 94),
    _SharedSentence(
        'I’ll get back to you tomorrow.', '내일 다시 연락드릴게요.', '회사', 'Joon', 61),
  ];

  static const _communityLanguage = '영어';

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

  void toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String communityId(_SharedSentence sentence) =>
      MySentenceStore.idFor(_communityLanguage, sentence.text);

  bool isSaved(_SharedSentence sentence) =>
      mine.any((item) => item.id == communityId(sentence));

  bool isParrotActive(_SharedSentence sentence) =>
      isSaved(sentence) &&
      (activities[communityId(sentence)]?.routineEnabled ?? true);

  Future<void> toggleSave(_SharedSentence sentence) async {
    try {
      if (isSaved(sentence)) {
        await MySentenceStore.remove(accountId, communityId(sentence));
        if (mounted) toast('내 문장에서 뺐어요.');
      } else {
        await MySentenceStore.add(
          accountId,
          language: _communityLanguage,
          text: sentence.text,
          translation: sentence.translation,
          topic: sentence.topic,
        );
        if (mounted) toast('내 문장에 저장했어요. 홈 앵무새가 말해줘요.');
      }
    } catch (_) {
      if (mounted) toast('저장하지 못했어요. 다시 시도해주세요.');
    }
  }

  Future<void> toggleParrot(_SharedSentence sentence) async {
    try {
      final id = communityId(sentence);
      if (!isSaved(sentence)) {
        await MySentenceStore.add(
          accountId,
          language: _communityLanguage,
          text: sentence.text,
          translation: sentence.translation,
          topic: sentence.topic,
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
    final input = await showDialog<_NewSentence>(
      context: context,
      builder: (context) => _AddSentenceDialog(language: language),
    );
    if (!mounted || input == null) return;
    try {
      final added = await MySentenceStore.add(
        accountId,
        language: language,
        text: input.text,
        translation: input.translation,
      );
      if (mounted) {
        toast(added ? '추가했어요. 홈 앵무새가 말해줘요.' : '이미 있는 문장이에요.');
      }
    } catch (_) {
      if (mounted) toast('문장을 저장하지 못했어요. 다시 시도해주세요.');
    }
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
    final basicSentences = defaultSentencesFor(language);
    // 최근에 추가한 문장이 맨 위에 오도록 뒤집고, 기본 문장은 그 아래에 둔다.
    final mySentences = [
      ...mine.where((item) => item.language == language).toList().reversed,
      ...basicSentences,
    ];
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
          onChanged: (value) => setState(() => language = value),
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
              title: '기본 $language 회화',
              subtitle: '앵무새가 처음부터 알고 있는 ${basicSentences.length}문장'),
          const SizedBox(height: 10),
          ...basicSentences.map((sentence) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _DefaultSentenceTile(sentence: sentence),
              )),
          const SizedBox(height: 20),
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
          const _SectionTitle(
              title: '사람들이 좋아한 문장', subtitle: '저장해서 바로 연습할 수 있어요'),
          const SizedBox(height: 10),
          ...List.generate(communitySentences.length, (index) {
            final sentence = communitySentences[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SentenceCard(
                sentence: sentence,
                liked: liked.contains(index),
                saved: isSaved(sentence),
                active: isParrotActive(sentence),
                onLike: () => setState(() => liked.contains(index)
                    ? liked.remove(index)
                    : liked.add(index)),
                onSave: () => toggleSave(sentence),
                onParrot: () => toggleParrot(sentence),
              ),
            );
          }),
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

class _DefaultSentenceTile extends StatelessWidget {
  const _DefaultSentenceTile({required this.sentence});

  final DefaultConversationSentence sentence;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 13, 12, 13),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colors.primaryContainer.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              sentence.topic,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sentence.text,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${sentence.translation} · ${sentence.pronunciation}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '소리 듣기',
            visualDensity: VisualDensity.compact,
            onPressed: () {},
            icon: const Icon(Icons.volume_up_rounded, size: 20),
          ),
        ],
      ),
    );
  }
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
    required this.liked,
    required this.saved,
    required this.active,
    required this.onLike,
    required this.onSave,
    required this.onParrot,
  });

  final _SharedSentence sentence;
  final bool liked;
  final bool saved;
  final bool active;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onParrot;

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant)),
        clipBehavior: Clip.antiAlias,
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
              Text('@${sentence.author}',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11)),
            ]),
            const SizedBox(height: 12),
            Text(sentence.text,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
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
                      liked ? Icons.favorite_rounded : Icons.favorite_border,
                      color: liked ? const Color(0xFFFF768B) : null)),
              Text('${sentence.likes + (liked ? 1 : 0)}',
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
      );
}

class _MySentenceTile extends StatelessWidget {
  const _MySentenceTile({required this.sentence, required this.accountId});

  final DefaultConversationSentence sentence;
  final String accountId;

  Future<void> openDetails(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => _SentenceDetailSheet(
          sentence: sentence,
          accountId: accountId,
        ),
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
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      );
}

class _SentenceDetailSheet extends StatefulWidget {
  const _SentenceDetailSheet({
    required this.sentence,
    required this.accountId,
  });

  final DefaultConversationSentence sentence;
  final String accountId;

  @override
  State<_SentenceDetailSheet> createState() => _SentenceDetailSheetState();
}

class _SentenceDetailSheetState extends State<_SentenceDetailSheet> {
  SentenceActivity activity = const SentenceActivity();
  bool loading = true;
  bool changingRoutine = false;

  @override
  void initState() {
    super.initState();
    loadActivity();
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

  Future<void> shareSentence() async {
    final renderBox = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        title: 'Parrokit 문장',
        subject: widget.sentence.text,
        text: '${widget.sentence.text}\n'
            '${widget.sentence.translation}\n'
            '${widget.sentence.pronunciation}\n\n'
            'Parrokit에서 함께 연습해요.',
        sharePositionOrigin: renderBox == null
            ? null
            : renderBox.localToGlobal(Offset.zero) & renderBox.size,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
              const Spacer(),
              IconButton(
                tooltip: '문장 공유',
                onPressed: shareSentence,
                icon: const Icon(Icons.ios_share_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            widget.sentence.text,
            style: const TextStyle(
              fontSize: 26,
              height: 1.25,
              fontWeight: FontWeight.w900,
            ),
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
          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(
                child: _ActivityCountCard(
                  icon: Icons.record_voice_over_rounded,
                  label: '앵무새가 말함',
                  count: activity.parrotSpeakCount,
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
          const SizedBox(height: 18),
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
          if (widget.sentence.id.startsWith('my-')) ...[
            TextButton.icon(
              onPressed: removeSentence,
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('내 문장에서 삭제'),
            ),
          ],
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: shareSentence,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const Icon(Icons.ios_share_rounded),
            label: const Text('다른 사람과 공유하기'),
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

class _SharedSentence {
  const _SharedSentence(
      this.text, this.translation, this.topic, this.author, this.likes);
  final String text;
  final String translation;
  final String topic;
  final String author;
  final int likes;
}

class _NewSentence {
  const _NewSentence(this.text, this.translation);
  final String text;
  final String translation;
}

class _AddSentenceDialog extends StatefulWidget {
  const _AddSentenceDialog({required this.language});

  final String language;

  @override
  State<_AddSentenceDialog> createState() => _AddSentenceDialogState();
}

class _AddSentenceDialogState extends State<_AddSentenceDialog> {
  final textController = TextEditingController();
  final translationController = TextEditingController();

  @override
  void dispose() {
    textController.dispose();
    translationController.dispose();
    super.dispose();
  }

  void submit() {
    final text = textController.text.trim();
    if (text.isEmpty) return;
    Navigator.pop(
      context,
      _NewSentence(text, translationController.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('${widget.language} 문장 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              autofocus: true,
              maxLength: 80,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: '연습할 문장'),
            ),
            TextField(
              controller: translationController,
              maxLength: 80,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => submit(),
              decoration: const InputDecoration(hintText: '뜻 (선택)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(onPressed: submit, child: const Text('추가')),
        ],
      );
}
