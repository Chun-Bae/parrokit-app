import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:parrokit/core/app/config/app_config.dart';
import 'package:parrokit/core/content/script_splitter.dart';
import 'package:parrokit/core/content/sentence_transfer.dart';
import 'package:parrokit/core/content/sentence_url_import.dart';
import 'package:parrokit/core/app/router/app_shell.dart' show hideNavBarWhile;
import 'package:parrokit/core/content/default_conversation_sentences.dart';
import 'package:parrokit/core/content/my_sentence_store.dart';
import 'package:parrokit/core/content/sentence_mastery.dart';
import 'package:parrokit/core/content/sentence_activity_store.dart';
import 'package:parrokit/core/content/shared_sentence_repository.dart';
import 'package:parrokit/core/shared/widgets/learning_language_picker.dart';
import 'package:parrokit/core/shared/widgets/sentence_affinity_bar.dart';
import 'clip_sentence_matches_section.dart';
import 'package:parrokit/features/home/dashboard/presentation/add_sentence_screen.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class SentenceCollectionPreview extends StatefulWidget {
  const SentenceCollectionPreview(
      {super.key, this.repository, this.urlFetcher});

  /// 주소에서 파일을 내려받는 함수. 비우면 실제로 내려받는다.
  final Future<Uint8List> Function(Uri uri)? urlFetcher;

  /// 둘러보기 공개 문장 저장소. 비우면 Firestore를 쓴다.
  final SharedSentenceRepository? repository;

  @override
  State<SentenceCollectionPreview> createState() =>
      _SentenceCollectionPreviewState();
}

class _SentenceCollectionPreviewState extends State<SentenceCollectionPreview> {
  bool explore = AppConfig.sentenceExplore;
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
    SharedSentenceRepository.revision.addListener(reloadSharedQuietly);
  }

  /// 공개·공개 취소·공개한 문장 삭제가 있으면 둘러보기 목록을 조용히 다시 읽는다.
  void reloadSharedQuietly() {
    if (loadedOnce) loadShared(silent: true);
  }

  @override
  void dispose() {
    SentenceActivityStore.revision.removeListener(reload);
    SharedSentenceRepository.revision.removeListener(reloadSharedQuietly);
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

  /// 당겨서 새로고침하거나 새로고침 버튼을 눌렀을 때. 목록을 비우지 않고 내 문장 저장 상태도 다시 읽는다.
  Future<void> refreshExplore() async {
    await Future.wait([reload(), loadShared(silent: true)]);
  }

  Future<void> loadShared({bool silent = false}) async {
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
    if (!silent) {
      setState(() {
        sharedLoading = true;
        sharedFailed = false;
      });
    }
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
        sharedFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      if (silent && shared.isNotEmpty) {
        // 새로고침에 실패해도 보던 목록은 그대로 둔다.
        toast('새로고침하지 못했어요. 다시 시도해주세요.');
        return;
      }
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

  /// 이 공개 문장과 같은 내 문장. 내가 올린 문장(같은 문서)이거나, 저장한 사본이거나,
  /// 같은 언어에 같은 문장이면 저장한 것으로 본다. 없으면 null.
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

  /// 루틴·횟수 기록에 쓰는 문장 id. 저장했으면 내 문장의 id, 아니면 공개 문장의 id.
  String communityId(SharedSentence sentence) =>
      savedCopyOf(sentence)?.id ?? sentence.id;

  bool isSaved(SharedSentence sentence) => savedCopyOf(sentence) != null;

  /// 내가 올린 공개 문장. 공개 문장과 내 문장이 같은 문서라서 저장 해제로 지우지 않는다.
  bool isMine(SharedSentence sentence) =>
      accountId != 'guest' && sentence.authorId == accountId;

  bool isParrotActive(SharedSentence sentence) =>
      isSaved(sentence) &&
      (activities[communityId(sentence)]?.routineEnabled ?? true);

  /// 가져간 사람 수를 올린다. 세지 못해도 저장은 그대로 두고 조용히 넘어간다.
  Future<void> countImport(SharedSentence sentence) async {
    final repo = repository;
    if (repo == null || accountId == 'guest' || isMine(sentence)) return;
    try {
      final counted = await repo.recordImport(
        sharedId: sentence.id,
        viewerId: accountId,
      );
      if (!counted || !mounted) return;
      setState(() {
        shared = [
          for (final item in shared)
            if (item.id == sentence.id)
              item.copyWith(importCount: item.importCount + 1)
            else
              item,
        ];
      });
    } catch (_) {/* 가져온 수만 못 올리고 문장은 저장돼 있다. */}
  }

  Future<void> toggleSave(SharedSentence sentence) async {
    try {
      if (isSaved(sentence)) {
        if (isMine(sentence)) {
          toast('내가 올린 문장이에요. 지우려면 내 문장에서 삭제해주세요.');
          return;
        }
        await MySentenceStore.remove(accountId, communityId(sentence));
        await reload();
        if (mounted) toast('내 문장에서 뺐어요.');
      } else {
        final added = await MySentenceStore.add(
          accountId,
          language: sentence.language,
          text: sentence.text,
          translation: sentence.translation,
          topic: sentence.topic,
          author: sentence.authorName,
          authorId: sentence.authorId,
          sourceSharedId: sentence.id,
        );
        if (added) await countImport(sentence);
        // 로그인하지 않은 기기 저장은 알림이 없어서 직접 다시 읽어 카드 표시를 바꾼다.
        await reload();
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
        onSaveShared: () => toggleSave(sentence),
        sentence: DefaultConversationSentence(
          id: communityId(sentence),
          language: sentence.language,
          text: sentence.text,
          translation: sentence.translation,
          pronunciation: sentence.pronunciation,
          topic: sentence.topic,
          author: sentence.authorName,
          authorId: sentence.authorId,
        ),
      );

  Future<void> toggleParrot(SharedSentence sentence) async {
    try {
      if (!isSaved(sentence)) {
        final added = await MySentenceStore.add(
          accountId,
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
        // 저장하면 내 문장에 새 id가 생기니, 그 id로 루틴을 켠다.
        final saved = await MySentenceStore.findByText(
            accountId, sentence.language, sentence.text);
        if (saved != null) {
          await SentenceActivityStore.setRoutineEnabled(
              accountId, saved.id, true);
        }
        await reload();
        if (mounted) toast('앵무새에게 보냈어요.');
        return;
      }
      final next = !isParrotActive(sentence);
      await SentenceActivityStore.setRoutineEnabled(
          accountId, communityId(sentence), next);
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

  /// 내 문장(가져온 문장 포함, 모든 언어)을 CSV나 엑셀(xlsx) 파일로 내보낸다.
  Future<void> exportMySentences({required bool xlsx}) async {
    if (mine.isEmpty) {
      toast('내보낼 문장이 없어요.');
      return;
    }
    try {
      final dir = await getTemporaryDirectory();
      final file =
          File('${dir.path}/parrokit_sentences.${xlsx ? 'xlsx' : 'csv'}');
      if (xlsx) {
        await file.writeAsBytes(SentenceTransfer.exportXlsx(mine));
      } else {
        await file.writeAsString(SentenceTransfer.exportCsv(mine));
      }
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        title: 'Parrokit 내 문장',
      ));
    } catch (_) {
      if (mounted) toast('문장을 내보내지 못했어요. 다시 시도해주세요.');
    }
  }

  /// CSV나 엑셀(xlsx) 파일에서 문장을 가져온다. 원문만 있으면 되고 뜻은 있으면 함께 넣는다.
  /// 언어 열이 없거나 비어 있으면 지금 고른 언어로 들어가고, 이미 있는 문장은 건너뛴다.
  /// 사용자가 복사해 붙여넣은 스크립트를 문장으로 나눠 고른 문장만 내 문장에 추가한다.
  Future<void> addFromScript() async {
    final picked = await hideNavBarWhile(showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ScriptImportSheet(),
    ));
    if (picked == null || picked.isEmpty) return;
    try {
      var added = 0;
      for (final text in picked) {
        final ok = await MySentenceStore.add(
          accountId,
          language: language,
          text: text,
          author: authorName,
        );
        if (ok) added++;
      }
      if (!mounted) return;
      final skipped = picked.length - added;
      toast(skipped == 0
          ? '문장 $added개를 추가했어요.'
          : '문장 $added개를 추가했어요. 이미 있는 $skipped개는 건너뛰었어요.');
    } catch (_) {
      if (mounted) toast('문장을 추가하지 못했어요. 다시 시도해주세요.');
    }
  }

  Future<void> importMySentences() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'xlsx', 'tsv', 'txt'],
        withData: true,
      );
      final file = picked?.files.single;
      final bytes = file?.bytes;
      if (file == null || bytes == null) return;
      await saveImported(SentenceTransfer.parse(bytes, file.name));
    } on FormatException {
      if (mounted) toast('파일을 읽지 못했어요. 문장, 뜻 열이 있는 CSV나 엑셀 파일인지 확인해주세요.');
    } catch (_) {
      if (mounted) toast('문장을 가져오지 못했어요. 다시 시도해주세요.');
    }
  }

  /// 주소를 입력받아 그 주소의 CSV·엑셀 파일을 내려받아 가져온다.
  Future<void> importFromUrl() async {
    final input = await showDialog<String>(
      context: context,
      builder: (context) => const _UrlImportDialog(),
    );
    if (input == null || !mounted) return;
    try {
      final uri = SentenceUrlImport.downloadUri(input);
      final bytes = await (widget.urlFetcher ?? SentenceUrlImport.fetch)(uri);
      await saveImported(SentenceTransfer.parseDownloaded(bytes));
    } on FormatException catch (e) {
      if (!mounted) return;
      toast(e.message.startsWith('https')
          ? e.message
          : '파일을 읽지 못했어요. 누구나 볼 수 있는 CSV·엑셀 파일 주소인지 확인해주세요.');
    } catch (_) {
      if (mounted) toast('주소에서 파일을 내려받지 못했어요. 주소와 공개 설정을 확인해주세요.');
    }
  }

  /// 가져온 문장을 내 문장에 추가하고 결과를 알린다. 이미 있는 문장은 건너뛴다.
  Future<void> saveImported(List<ImportedSentence> items) async {
    try {
      if (items.isEmpty) {
        toast('가져올 문장이 없어요.');
        return;
      }
      var added = 0;
      for (final item in items) {
        final ok = await MySentenceStore.add(
          accountId,
          language: item.language.isEmpty ? language : item.language,
          text: item.text,
          translation: item.translation,
          pronunciation: item.pronunciation,
          author: authorName,
        );
        if (ok) added++;
      }
      if (!mounted) return;
      final skipped = items.length - added;
      toast(skipped == 0
          ? '문장 $added개를 가져왔어요.'
          : '문장 $added개를 가져왔어요. 이미 있는 $skipped개는 건너뛰었어요.');
    } catch (_) {
      if (mounted) toast('문장을 가져오지 못했어요. 다시 시도해주세요.');
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
    return RefreshIndicator(
        onRefresh: refreshExplore,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          key: const PageStorageKey('sentence-collection-preview'),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 140),
          children: [
            _ViewSwitch(
                explore: explore,
                onChanged: (value) {
                  setState(() => explore = value);
                  AppConfig.sentenceExplore = value;
                  AppConfig.saveToPrefs();
                }),
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
                  trailing:
                      TextButton(onPressed: () {}, child: const Text('전체'))),
              const SizedBox(height: 10),
              SizedBox(
                height: 148,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: packs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) =>
                      _PackCard(pack: packs[index]),
                ),
              ),
              const SizedBox(height: 28),
              _SectionTitle(
                  title: '공유된 문장',
                  subtitle: '다른 사람이 공유한 문장을 저장해서 연습해요',
                  trailing: IconButton(
                      key: const ValueKey('refresh-shared'),
                      tooltip: '새로고침',
                      onPressed: sharedLoading ? null : refreshExplore,
                      icon: const Icon(Icons.refresh_rounded))),
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
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        const Text('홈 앵무새가 순서대로 말해줘요',
                            style: TextStyle(fontSize: 12)),
                      ])),
                ]),
              ),
              const SizedBox(height: 24),
              _SectionTitle(
                  title: '내 문장',
                  subtitle: '최근 추가한 순서',
                  trailing: PopupMenuButton<String>(
                    tooltip: '가져오기·내보내기',
                    icon: const Icon(Icons.more_horiz_rounded),
                    onSelected: (value) => switch (value) {
                      'script' => addFromScript(),
                      'import' => importMySentences(),
                      'url' => importFromUrl(),
                      'xlsx' => exportMySentences(xlsx: true),
                      _ => exportMySentences(xlsx: false),
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'script',
                          child: ListTile(
                              leading: Icon(Icons.content_paste_rounded),
                              title: Text('스크립트 붙여넣어 문장 만들기'))),
                      PopupMenuItem(
                          value: 'import',
                          child: ListTile(
                              leading: Icon(Icons.file_download_outlined),
                              title: Text('CSV·엑셀에서 가져오기'))),
                      PopupMenuItem(
                          value: 'url',
                          child: ListTile(
                              leading: Icon(Icons.link_rounded),
                              title: Text('주소(URL)에서 가져오기'))),
                      PopupMenuItem(
                          value: 'csv',
                          child: ListTile(
                              leading: Icon(Icons.file_upload_outlined),
                              title: Text('CSV로 내보내기'))),
                      PopupMenuItem(
                          value: 'xlsx',
                          child: ListTile(
                              leading: Icon(Icons.table_chart_outlined),
                              title: Text('엑셀(xlsx)로 내보내기'))),
                    ],
                  )),
              const SizedBox(height: 10),
              ...List.generate(mySentences.length, (index) {
                final sentence = mySentences[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MySentenceTile(
                    sentence: sentence,
                    accountId: accountId,
                    activity:
                        activities[sentence.id] ?? const SentenceActivity(),
                    repository: repository,
                    authorName: authorName,
                  ),
                );
              }),
            ],
          ],
        ));
  }
}

/// CSV·엑셀 파일 주소를 입력받는 창. 확인하면 입력한 주소를 돌려준다.
class _UrlImportDialog extends StatefulWidget {
  const _UrlImportDialog();

  @override
  State<_UrlImportDialog> createState() => _UrlImportDialogState();
}

class _UrlImportDialogState extends State<_UrlImportDialog> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('주소(URL)에서 가져오기'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey('url-import-input'),
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                hintText: 'https://…/sentences.csv',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'https 주소의 CSV·엑셀(xlsx) 파일을 읽어요. 구글 스프레드시트는 "링크가 있는 모든 사용자 보기" 공유 주소를 그대로 붙여넣으면 돼요. '
              '열 순서는 문장, 뜻, 발음이고 5MB까지 가져올 수 있어요.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('취소')),
          FilledButton(
              key: const ValueKey('url-import-confirm'),
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('가져오기')),
        ],
      );
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
        key: ValueKey(saved ? 'sentence-card-saved' : 'sentence-card-unsaved'),
        // 내 문장으로 가져온 문장은 연한 색과 테두리로 구분한다.
        color: saved
            ? Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: 0.35)
            : Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
                color: saved
                    ? Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.5)
                    : Theme.of(context).colorScheme.outlineVariant)),
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
                if (saved) ...[
                  const SizedBox(width: 6),
                  Container(
                      key: const ValueKey('saved-chip'),
                      padding: const EdgeInsets.fromLTRB(6, 4, 8, 4),
                      decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(20)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.check_rounded,
                            size: 12,
                            color: Theme.of(context).colorScheme.onPrimary),
                        const SizedBox(width: 3),
                        Text('저장됨',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.w800)),
                      ])),
                ],
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
                const SizedBox(width: 14),
                Tooltip(
                  message: '가져간 사람 수',
                  child: Row(children: [
                    Icon(Icons.download_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 3),
                    Text('${sentence.importCount}',
                        key: const ValueKey('shared-import-count'),
                        style: const TextStyle(fontSize: 12)),
                  ]),
                ),
                const Spacer(),
                IconButton(
                    tooltip: '내 문장에 저장',
                    visualDensity: VisualDensity.compact,
                    onPressed: onSave,
                    icon: Icon(
                        saved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        color: saved
                            ? Theme.of(context).colorScheme.primary
                            : null)),
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
  Future<void> Function()? onSaveShared,
}) =>
    hideNavBarWhile(showModalBottomSheet<void>(
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
        onSaveShared: onSaveShared,
      ),
    ));

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

  /// 최고 단계 카드의 연한 황금 그라데이션 배경. 터치 물결이 그 위에 그려지도록 Ink를 쓴다.
  Widget _goldBackground(bool maxed, Widget child) => !maxed
      ? child
      : Ink(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFBEA), Color(0xFFFFF1C9), Color(0xFFFFFAE6)],
            ),
          ),
          child: child,
        );

  @override
  Widget build(BuildContext context) {
    final maxed = affinityOf(activity).isMax;
    final card = Material(
      color: maxed ? Colors.transparent : Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(maxed ? 15.5 : 17),
        side: maxed
            ? BorderSide.none
            : BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
      ),
      clipBehavior: Clip.antiAlias,
      child: _goldBackground(
        maxed,
        ListTile(
          onTap: () => openDetails(context),
          title: Text(
            sentence.text,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(sentence.translation, maxLines: 1),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MasteryBadge(
                  mastery: masteryOf(activity), affinity: affinityOf(activity)),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
    if (!maxed) return card;
    // 친밀도 최고 단계는 금색 그라데이션 테두리와 연한 황금빛 배경으로 표시한다.
    return Container(
      key: const ValueKey('sentence-card-gold'),
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF7D774), Color(0xFFC9972B), Color(0xFFFFE9A0)],
        ),
      ),
      child: card,
    );
  }
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
    this.onSaveShared,
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

  /// 둘러보기의 남의 문장을 내 문장으로 가져온다. 저장하지 않은 공개 문장일 때만 버튼이 보인다.
  final Future<void> Function()? onSaveShared;

  @override
  State<_SentenceDetailSheet> createState() => _SentenceDetailSheetState();
}

class _SentenceDetailSheetState extends State<_SentenceDetailSheet> {
  SentenceActivity activity = const SentenceActivity();
  bool loading = true;
  bool changingRoutine = false;

  final memoController = TextEditingController();
  final memoFocus = FocusNode();
  Timer? memoTimer;

  /// 마지막으로 저장한 메모. 바뀐 게 없으면 다시 저장하지 않는다.
  String savedMemo = '';

  /// 이 문장이 둘러보기에 공개돼 있는지. 모르면 null.
  bool? published;
  bool publishing = false;
  late bool sharedLiked = widget.shared?.liked ?? false;
  late int sharedLikes = widget.shared?.likeCount ?? 0;
  late final int sharedImports = widget.shared?.importCount ?? 0;

  static const _ttsLocales = {'영어': 'en-US', '일본어': 'ja-JP', '중국어': 'zh-CN'};
  final FlutterTts tts = FlutterTts();
  bool ttsReady = false;
  bool speaking = false;

  @override
  void initState() {
    super.initState();
    memoFocus.addListener(saveMemo);
    loadActivity();
    unawaited(setupTts());
    unawaited(loadPublished());
  }

  /// 내가 등록한 문장만 공유할 수 있다. 기본 문장이나 남이 올린 문장은 해당이 없다.
  /// 둘러보기에서 연 내 문장(공유 중)도 여기서 공유를 취소할 수 있다.
  bool get canPublish => widget.saved && publishBlockedReason == null;

  /// 공유할 수 없는 문장이면 그 이유. 공유할 수 있으면 null.
  String? get publishBlockedReason {
    if (widget.repository == null) return '지금은 공유 기능을 쓸 수 없어요.';
    if (!widget.sentence.id.startsWith('my-')) {
      return '기본 문장은 공유할 수 없어요. 내가 등록한 문장만 공유할 수 있어요.';
    }
    if (widget.sentence.authorId.isNotEmpty &&
        widget.sentence.authorId != widget.accountId) {
      return '다른 사람이 만든 문장은 공유할 수 없어요.';
    }
    return null;
  }

  Future<void> loadPublished() async {
    final repo = widget.repository;
    if (!canPublish || repo == null || widget.accountId == 'guest') return;
    try {
      final value = await repo.isPublished(sentenceId: widget.sentence.id);
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
    if (published == true) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          key: const ValueKey('unpublish-dialog'),
          title: const Text('공유를 취소할까요?'),
          content: const Text('둘러보기에서 사라지고 좋아요 수와 가져간 수도 함께 사라져요.\n'
              '이미 가져간 사람의 문장은 그대로 남아요. 내 문장함에는 계속 있어요.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('그대로 두기')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('공유 취소')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
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
          content: Text('공개되는 것: 문장, 뜻, 발음, 작성자 "${widget.authorName}"\n'
              '공개되지 않는 것: 들은 횟수, 연습 기록, 친밀도, 메모\n\n'
              '언제든 공유를 취소할 수 있어요. 하루에 ${SharedSentenceRepository.dailyShareLimit}개까지 공유할 수 있어요.'),
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
        await repo.unpublish(sentenceId: widget.sentence.id);
      } else {
        await repo.publish(
          sentenceId: widget.sentence.id,
          authorName: widget.authorName,
        );
      }
      final next = published != true;
      if (mounted) setState(() => published = next);
      messenger.showSnackBar(
          SnackBar(content: Text(next ? '둘러보기에 공유했어요.' : '공유를 취소했어요.')));
    } on ShareLimitReachedException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e 내일 다시 공유해주세요.')));
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
    memoTimer?.cancel();
    memoFocus.removeListener(saveMemo);
    // 시트를 바로 닫아도 쓰던 메모가 사라지지 않게 마지막으로 저장한다.
    saveMemo();
    memoController.dispose();
    memoFocus.dispose();
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
      savedMemo = loaded.memo;
      if (memoController.text.isEmpty) memoController.text = loaded.memo;
    });
  }

  void changeMemo(String _) {
    memoTimer?.cancel();
    memoTimer = Timer(const Duration(milliseconds: 800), saveMemo);
  }

  void saveMemo() {
    if (loading) return;
    final text = memoController.text.trim();
    if (text == savedMemo) return;
    savedMemo = text;
    unawaited(SentenceActivityStore.setMemo(
      widget.accountId,
      widget.sentence.id,
      text,
    ).catchError((Object _) {/* 저장 실패는 화면 흐름에 영향 주지 않는다. */}));
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('delete-dialog'),
        title: const Text('내 문장에서 삭제할까요?'),
        content: Text(published == true
            ? '지금 둘러보기에 공유 중인 문장이에요. 삭제하면 둘러보기에서도 사라지고 '
                '좋아요 수와 가져간 수도 함께 사라져요.\n이미 가져간 사람의 문장은 그대로 남아요.'
            : '삭제하면 이 문장의 연습 기록과 메모도 더 이상 볼 수 없어요.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
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
        MediaQuery.paddingOf(context).bottom,
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
              _MasteryBadge(
                  mastery: masteryOf(activity), affinity: affinityOf(activity)),
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
              if (widget.shared != null) ...[
                Text('$sharedLikes', style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 12),
                Icon(Icons.download_rounded,
                    size: 18, color: colors.onSurfaceVariant),
                const SizedBox(width: 3),
                Text('$sharedImports',
                    key: const ValueKey('detail-import-count'),
                    style: const TextStyle(fontSize: 12)),
              ],
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
          // 내 기록은 내 문장일 때만 보인다. 저장하지 않은 남의 문장에는 보이지 않는다.
          if (widget.saved) ...[
            const SizedBox(height: 22),
            const _PrivateSectionLabel(),
            const SizedBox(height: 12),
            SentenceAffinityBar(
              key: const ValueKey('sentence-affinity'),
              affinity: affinityOf(activity),
              loading: loading,
            ),
            const SizedBox(height: 14),
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
          ],
          if (widget.saved) ...[
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('sentence-memo'),
              controller: memoController,
              focusNode: memoFocus,
              enabled: !loading,
              minLines: 2,
              maxLines: 5,
              maxLength: 500,
              textInputAction: TextInputAction.newline,
              onChanged: changeMemo,
              onTapOutside: (_) => memoFocus.unfocus(),
              decoration: const InputDecoration(
                labelText: '메모',
                hintText: '이 문장에 대한 메모를 남겨 보세요',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 14),
          ClipSentenceMatchesSection(sentence: widget.sentence.text),
          const SizedBox(height: 10),
          if (!widget.saved &&
              widget.shared != null &&
              widget.onSaveShared != null) ...[
            FilledButton.icon(
              key: const ValueKey('save-shared-sentence'),
              onPressed: () async {
                final navigator = Navigator.of(context);
                await widget.onSaveShared!();
                if (navigator.mounted) navigator.pop();
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('내 문장으로 가져오기'),
            ),
            const SizedBox(height: 6),
          ],
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

/// 친밀도·들은 횟수·연습 기록·메모는 이 기기와 내 계정에만 있고 공유해도 공개되지 않는다.
class _PrivateSectionLabel extends StatelessWidget {
  const _PrivateSectionLabel();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      key: const ValueKey('private-section'),
      children: [
        Icon(Icons.lock_outline_rounded,
            size: 15, color: colors.onSurfaceVariant),
        const SizedBox(width: 6),
        Text('나만 보는 기록',
            style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w800)),
        const SizedBox(width: 8),
        Expanded(
          child: Text('공유해도 공개되지 않아요',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11)),
        ),
      ],
    );
  }
}

class _MasteryBadge extends StatelessWidget {
  const _MasteryBadge({required this.mastery, required this.affinity});

  final SentenceMastery mastery;
  final SentenceAffinity affinity;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = affinityChipColors(affinity.level);
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 2, 8, 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        SvgPicture.asset(
            'assets/badges/affinity_${affinity.level.clamp(1, SentenceAffinity.maxLevel)}.svg',
            width: 18,
            height: 18),
        const SizedBox(width: 3),
        Text(
          'Lv.${affinity.level} ${affinity.name}',
          style: TextStyle(
            color: foreground,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ]),
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

/// 붙여넣은 스크립트를 문장으로 나눠 보여주고, 체크한 문장만 돌려준다.
class _ScriptImportSheet extends StatefulWidget {
  const _ScriptImportSheet();

  @override
  State<_ScriptImportSheet> createState() => _ScriptImportSheetState();
}

class _ScriptImportSheetState extends State<_ScriptImportSheet> {
  final input = TextEditingController();
  List<String> sentences = [];
  Set<int> selected = {};
  bool split = false;

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  void runSplit() {
    final result = ScriptSplitter.split(input.text);
    setState(() {
      split = true;
      sentences = result;
      selected = {for (var i = 0; i < result.length; i++) i};
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final height = MediaQuery.sizeOf(context).height * 0.8;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('스크립트로 문장 만들기',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Container(
                key: const ValueKey('script-notice'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '유튜브 주소로 자막을 자동으로 가져오지는 않아요. '
                  '영상의 \'스크립트 표시\'에서 직접 복사해 붙여넣어 주세요. '
                  '저작권이 있는 영상의 문장은 개인 학습용으로만 쓰고 공유하지 마세요.',
                  style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.4),
                ),
              ),
              const SizedBox(height: 12),
              if (!split) ...[
                Expanded(
                  child: TextField(
                    key: const ValueKey('script-input'),
                    controller: input,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: '복사한 스크립트를 여기에 붙여넣어 주세요',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey('script-split'),
                    onPressed: input.text.trim().isEmpty ? null : runSplit,
                    child: const Text('문장 나누기'),
                  ),
                ),
              ] else if (sentences.isEmpty) ...[
                const Expanded(child: Center(child: Text('나눌 문장을 찾지 못했어요.'))),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => setState(() => split = false),
                    child: const Text('다시 붙여넣기'),
                  ),
                ),
              ] else ...[
                Row(children: [
                  Text('${selected.length} / ${sentences.length}개 선택',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => selected =
                        selected.length == sentences.length
                            ? {}
                            : {for (var i = 0; i < sentences.length; i++) i}),
                    child: Text(selected.length == sentences.length
                        ? '전체 해제'
                        : '전체 선택'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => split = false),
                    child: const Text('다시 붙여넣기'),
                  ),
                ]),
                Expanded(
                  child: ListView.builder(
                    key: const ValueKey('script-sentences'),
                    itemCount: sentences.length,
                    itemBuilder: (context, i) => CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: selected.contains(i),
                      title: Text(sentences[i]),
                      onChanged: (value) => setState(() {
                        if (value == true) {
                          selected.add(i);
                        } else {
                          selected.remove(i);
                        }
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey('script-add'),
                    onPressed: selected.isEmpty
                        ? null
                        : () => Navigator.pop(context, [
                              for (final i in (selected.toList()..sort()))
                                sentences[i],
                            ]),
                    child: Text('내 문장에 ${selected.length}개 추가'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
