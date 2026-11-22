import 'package:parrokit/features/collection/shared/shared_sentence_stats.dart';
import 'package:parrokit/core/shared/utils/optional_field_label.dart';
import 'package:parrokit/core/shared/utils/action_failed_text.dart';
import 'package:parrokit/core/content/shared_sentence_match.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/widgets/assist_icon.dart';
import 'package:parrokit/core/content/cloud_sentence_assist.dart';
import 'package:parrokit/core/content/sentence_assist.dart';
import 'package:parrokit/core/content/assist_usage_text.dart';
import 'package:parrokit/core/shared/theme/components/inputs/app_input_theme.dart';
import 'package:parrokit/core/shared/theme/app_spacing.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:parrokit/core/shared/utils/audio_focus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:parrokit/core/content/sentence_transfer.dart';
import 'package:parrokit/core/content/sentence_url_import.dart';
import 'package:parrokit/core/content/default_conversation_sentences.dart';
import 'package:parrokit/core/content/my_sentence_store.dart';
import 'package:parrokit/core/content/sentence_mastery.dart';
import 'package:parrokit/core/content/sentence_activity_store.dart';
import 'package:parrokit/core/content/shared_sentence_repository.dart';
import 'package:parrokit/core/content/practice_reward.dart';
import 'package:parrokit/core/content/speaking_xp.dart';
import 'package:parrokit/core/state/practice_reward_grant.dart';
import 'package:parrokit/core/content/practice_calendar.dart';
import 'package:parrokit/core/content/practice_log.dart';
import 'package:parrokit/core/speech/presentation/speech_practice_view.dart';
import 'package:parrokit/core/speech/phrase_recognizer.dart';
import 'package:parrokit/core/shared/widgets/sentence_affinity_bar.dart';
import 'clip_sentence_matches_section.dart';
import 'package:parrokit/features/collection/library/presentation/widgets/swipe_action_tile.dart';
import '../open_shared_sentences.dart';
import 'sentence_import_method_dialog.dart';
import 'sentence_import_sheet.dart';
import 'word_collection_preview.dart' show AddWordSheet, wordAddResultText;
import 'package:parrokit/features/home/dashboard/presentation/add_sentence_screen.dart';
import 'package:parrokit/core/state/provider/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/features/collection/shared/collection_tokens.dart';
import 'package:parrokit/core/shared/widgets/app_bottom_sheet.dart';
import 'package:parrokit/core/shared/widgets/speak_controls.dart';
import 'package:parrokit/core/content/my_word_store.dart';
import 'package:parrokit/core/content/sentence_share_text.dart';
import 'share_my_sentence_sheet.dart';
import 'package:parrokit/core/content/sentence_topic_label.dart';
import 'package:parrokit/core/shared/widgets/author_avatar.dart';
import 'package:parrokit/core/shared/utils/sentence_age_label.dart';
import 'package:parrokit/core/shared/widgets/tiered_header.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/sentence_filter_row.dart';
import 'collection_header_slot.dart';

class SentenceCollectionPreview extends StatefulWidget {
  const SentenceCollectionPreview({
    super.key,
    this.repository,
    this.urlFetcher,
    this.exploreOnly = false,
    this.headerSlot,
  });

  /// 언어·주제 줄과 둘러보기 줄을 보관함 머리줄로 올려 둘 자리(5차 336).
  /// 비우면 예전처럼 이 화면 목록 안에 둔다(둘러보기 전용 화면).
  final CollectionHeaderSlot? headerSlot;

  /// true면 둘러보기 목록으로 그린다(커뮤니티 문장 탭, 5차 340).
  /// false면 보관함 문장 탭: 위에 둘러보기 한 줄, 아래 내 문장 목록.
  /// 전에는 한 화면 안에서 "내 문장 / 둘러보기" 탭으로 바꿔 봤다.
  final bool exploreOnly;

  /// 주소에서 파일을 내려받는 함수. 비우면 실제로 내려받는다.
  final Future<Uint8List> Function(Uri uri)? urlFetcher;

  /// 둘러보기 공개 문장 저장소. 비우면 Firestore를 쓴다.
  final SharedSentenceRepository? repository;

  @override
  State<SentenceCollectionPreview> createState() =>
      _SentenceCollectionPreviewState();
}

class _SentenceCollectionPreviewState extends State<SentenceCollectionPreview> {
  bool get explore => widget.exploreOnly;

  final _swipeKeys = <String, GlobalKey<SwipeActionTileState>>{};

  /// 둘러보기 화면의 공유 문장 정렬. true면 좋아요 순, false면 최신 순.
  bool sortPopular = true;
  String language = '영어';
  String category = allSentenceTopics;
  String accountId = 'guest';

  /// 지금 둘러보기에 공개 중인 내 문장 id들('공유 중' 칩, 5차).
  Set<String> publishedIds = <String>{};
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

  @override
  void initState() {
    super.initState();
    SentenceActivityStore.revision.addListener(reload);
    // 좋아요·친밀도·메모처럼 목록 자체는 그대로인 변화. 전에는 듣지 않아서,
    // 상세에서 하트를 눌러도 목록은 앱을 다시 켤 때까지 그대로였다(5차).
    SentenceActivityStore.activityRevision.addListener(reloadActivities);
    SharedSentenceRepository.revision.addListener(reloadSharedQuietly);
  }

  /// 문장 목록은 그대로 두고 활동 기록만 다시 읽는다.
  Future<void> reloadActivities() async {
    final requested = accountId;
    try {
      final loaded = await SentenceActivityStore.loadAll(requested);
      if (!mounted || requested != accountId) return;
      setState(() => activities = loaded);
    } catch (_) {
      // 못 읽으면 지금 값을 그대로 둔다.
    }
  }

  /// 공개·공개 취소·공개한 문장 삭제가 있으면 둘러보기 목록을 조용히 다시 읽는다.
  void reloadSharedQuietly() {
    if (loadedOnce) loadShared(silent: true);
    unawaited(loadPublishedIds());
  }

  /// 내 문장 목록에 '공유 중' 칩을 붙이려고 읽는다(5차, 사용자 요청).
  Future<void> loadPublishedIds() async {
    final requested = accountId;
    try {
      final ids = await MySentenceStore.publishedIds(requested);
      if (!mounted || requested != accountId) return;
      setState(() => publishedIds = ids);
    } catch (_) {
      // 못 읽으면 칩만 안 보인다.
    }
  }

  @override
  void dispose() {
    SentenceActivityStore.revision.removeListener(reload);
    SentenceActivityStore.activityRevision.removeListener(reloadActivities);
    SharedSentenceRepository.revision.removeListener(reloadSharedQuietly);
    super.dispose();
  }

  Future<void> reload() async {
    final requested = accountId;
    try {
      final results = await Future.wait([
        MySentenceStore.load(requested),
        SentenceActivityStore.loadAll(requested),
        MySentenceStore.publishedIds(requested),
      ]);
      if (!mounted || requested != accountId) return;
      setState(() {
        mine = results[0] as List<DefaultConversationSentence>;
        activities = results[1] as Map<String, SentenceActivity>;
        publishedIds = results[2] as Set<String>;
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
        toast('새로고침하지 못했어요. 다시 시도해 주세요.');
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
      toast(likeNeedsLoginMessage);
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
        toast(likeFailedMessage);
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
  DefaultConversationSentence? savedCopyOf(SharedSentence sentence) =>
      savedCopyOfShared(mine, sentence);

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
          toast(sentenceIsMineMessage);
          return;
        }
        await MySentenceStore.remove(accountId, communityId(sentence));
        await reload();
        if (mounted) toast(sentenceRemovedFromMineMessage);
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
        if (mounted) toast(sentenceSavedToMineMessage);
      }
    } catch (_) {
      if (mounted) toast(saveFailedMessage);
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
      if (mounted) toast(settingsSaveFailedMessage);
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
      toast(result.added
          ? sentenceSavedToMineMessage
          : sentenceAlreadySavedMessage);
    } catch (_) {
      if (mounted) toast(sentenceSaveFailedMessage);
    }
  }

  /// 내 문장(가져온 문장 포함, 모든 언어)을 CSV나 엑셀(xlsx) 파일로 내보낸다.
  /// 내보낼 파일 모양을 먼저 고르게 한다(5차 344, 사용자 요청).
  Future<void> exportSentences() async {
    if (mine.isEmpty) {
      toast('내보낼 문장이 없어요.');
      return;
    }
    final xlsx = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('export-format-dialog'),
        title: const Text('어떤 파일로 내보낼까요?'),
        content: const Text('둘 다 같은 양식이에요. 엑셀에서 바로 열려면 엑셀(xlsx), '
            '다른 앱에서도 두루 쓰려면 CSV를 고르세요.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
              key: const ValueKey('export-csv'),
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CSV')),
          FilledButton(
              key: const ValueKey('export-xlsx'),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('엑셀(xlsx)')),
        ],
      ),
    );
    if (xlsx == null || !mounted) return;
    await exportMySentences(xlsx: xlsx);
  }

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
      if (mounted) toast('문장을 내보내지 못했어요. 다시 시도해 주세요.');
    }
  }

  /// CSV나 엑셀(xlsx) 파일에서 문장을 가져온다. 원문만 있으면 되고 뜻은 있으면 함께 넣는다.
  /// 언어 열이 없거나 비어 있으면 지금 고른 언어로 들어가고, 이미 있는 문장은 건너뛴다.
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
      if (mounted) toast('파일을 읽지 못했어요. 문장, 뜻 열이 있는 CSV나 엑셀 파일인지 확인해 주세요.');
    } catch (_) {
      if (mounted) toast('문장을 가져오지 못했어요. 다시 시도해 주세요.');
    }
  }

  NavigatorState? _progressNavigator;

  /// 가져오는 동안 닫을 수 없는 진행 창을 띄운다. 끝나면 [hideImportProgress]로 닫는다.
  /// 창은 맨 위(루트) 내비게이터에 뜨므로, 닫을 때도 같은 내비게이터를 써야 화면이 같이 닫히지 않는다.
  void showImportProgress(ValueNotifier<_ImportProgress> progress) {
    if (!mounted || _progressNavigator != null) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    _progressNavigator = navigator;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) => _ImportProgressDialog(progress: progress),
    );
  }

  void hideImportProgress() {
    final navigator = _progressNavigator;
    if (navigator == null) return;
    _progressNavigator = null;
    if (navigator.mounted) navigator.pop();
  }

  /// CSV·엑셀 가져오기 창을 열고, 고른 방법(파일 또는 주소)으로 가져온다.
  Future<void> importSentences() async {
    final source = await showDialog<SentenceImportSource>(
      context: context,
      builder: (context) => const SentenceImportMethodDialog(),
    );
    if (source == null || !mounted) return;
    final url = source.url;
    if (url == null) {
      await importMySentences();
    } else {
      await importFromUrl(url);
    }
  }

  /// 입력한 주소의 CSV·엑셀 파일을 내려받아 가져온다.
  Future<void> importFromUrl(String input) async {
    try {
      final uri = SentenceUrlImport.downloadUri(input);
      final progress = ValueNotifier<_ImportProgress>(
          const _ImportProgress('주소에서 파일을 받는 중이에요…'));
      Uint8List bytes;
      try {
        showImportProgress(progress);
        bytes = await (widget.urlFetcher ?? SentenceUrlImport.fetch)(uri);
      } finally {
        hideImportProgress();
        progress.dispose();
      }
      if (!mounted) return;
      await saveImported(SentenceTransfer.parseDownloaded(bytes));
    } on SentenceUrlException catch (e) {
      if (mounted) toast(e.message);
    } on FormatException {
      if (mounted) toast('파일을 읽지 못했어요. 누구나 볼 수 있는 CSV·엑셀 파일 주소인지 확인해 주세요.');
    } catch (_) {
      if (mounted) toast('주소에서 파일을 내려받지 못했어요. 주소와 공개 설정을 확인해 주세요.');
    }
  }

  /// 가져올 문장을 바로 등록하지 않고 목록 시트로 먼저 보여준다.
  /// 고른 문장만 옮기고, 끝나면 완료하거나 취소(되돌리기)할 수 있다.
  Future<void> saveImported(List<ImportedSentence> items) async {
    if (items.isEmpty) {
      toast('가져올 문장이 없어요.');
      return;
    }
    try {
      final result = await showSentenceImportSheet(
        context,
        items: items,
        defaultLanguage: language,
        existingKeys: {
          for (final item in mine) sentenceImportKey(item.language, item.text),
        },
        addOne: (item) async {
          final itemLanguage = item.language.isEmpty ? language : item.language;
          final added = await MySentenceStore.add(
            accountId,
            language: itemLanguage,
            text: item.text,
            translation: item.translation,
            pronunciation: item.pronunciation,
            author: authorName,
          );
          if (!added) return null;
          final saved = await MySentenceStore.findByText(
              accountId, itemLanguage, item.text);
          return saved?.id ?? '';
        },
        removeOne: (id) => MySentenceStore.remove(accountId, id),
      );
      await reload();
      if (!mounted || result == null) return;
      toast('문장 ${result.added}개를 가져왔어요.');
    } catch (_) {
      if (mounted) toast('문장을 가져오지 못했어요. 다시 시도해 주세요.');
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
    // 최근에 추가한 문장이 맨 위에 온다. 기본으로 주던 예시 문장은 없앴다(5차).
    final mySentences = mine
        .where((item) => item.language == language)
        .toList()
        .reversed
        .toList();
    final visibleShared = (category == allSentenceTopics
        ? [...shared]
        : shared.where((item) => item.topic == category).toList());
    if (explore && sortPopular) {
      visibleShared.sort((a, b) => b.likeCount.compareTo(a.likeCount));
    }
    final routineCount = mySentences
        .where((item) => activities[item.id]?.routineEnabled ?? true)
        .length;
    // 언어·주제 줄과 둘러보기 줄. 보관함 안에서는 머리줄로 올라가고(5차 336),
    // 둘러보기 전용 화면에서는 예전처럼 목록 맨 위에 둔다.
    final filterRow = SentenceFilterRow(
      language: language,
      category: category,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      onLanguageChanged: (value) {
        setState(() => language = value);
        loadShared();
      },
      onCategoryChanged: (value) => setState(() => category = value),
    );
    final exploreRow = Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: _ExploreStrip(
        accountId: accountId,
        sentences: ([...visibleShared]
              ..sort((a, b) => b.likeCount.compareTo(a.likeCount)))
            .take(8)
            .toList(),
        loading: sharedLoading,
        failed: sharedFailed,
        onOpen: openCommunityDetails,
        onViewAll: () => openSharedSentences(context),
        onRetry: loadShared,
        emptyMessage: sharedSentencesEmptyMessage(
            category: category, anyShared: shared.isNotEmpty),
      ),
    );
    // 머리줄에 올리는 건 그리는 중이 아니라 그린 뒤에 한다.
    final slot = widget.headerSlot;
    if (slot != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        slot.put(
          // 언어·주제 54(여백 14 + 줄 40), 둘러보기 158(제목 + 카드 92 + 여백).
          heights: [54, if (!explore) 158],
          build: (index) => index == 0 ? filterRow : exploreRow,
        );
      });
    }

    return RefreshIndicator(
        onRefresh: refreshExplore,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          key: const PageStorageKey('sentence-collection-preview'),
          slivers: [
            if (slot == null) ...[
              SliverPersistentHeader(
                floating: true,
                delegate: TieredHeaderDelegate(tiers: [
                  HeaderTier(height: 54, child: filterRow),
                ]),
              ),
              if (!explore)
                SliverPersistentHeader(
                  floating: true,
                  delegate: TieredHeaderDelegate(tiers: [
                    HeaderTier(height: 158, child: exploreRow),
                  ]),
                ),
            ],
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 140),
              sliver: SliverList(
                  delegate: SliverChildListDelegate([
                if (explore) ...[
                  // 'Parrokit 제공' 문장 묶음 카드 셋은 뺐다(5차). '8문장 · 입문'처럼
                  // 보였지만 내용이 없는 자리표시라 눌러도 아무 일이 없었다(원칙 5).
                  // 실제 묶음이 생기면 이 자리에 다시 붙인다.
                  // 커뮤니티 '문장' 탭 안이라 큰 제목('공유된 문장')은 탭 이름과
                  // 겹쳤다(5차 343). 안내 한 줄과 고르는 칩만 남긴다.
                  Row(children: [
                    Expanded(
                      child: Text('저장해서 내 문장으로 연습해요',
                          style: context.texts.bodySmall.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                    ),
                    for (final (popular, label) in [
                      (true, '인기'),
                      (false, '최신')
                    ])
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: sortPopular == popular,
                          showCheckmark: false,
                          visualDensity: VisualDensity.compact,
                          onSelected: (_) =>
                              setState(() => sortPopular = popular),
                        ),
                      ),
                    IconButton(
                        key: const ValueKey('refresh-shared'),
                        tooltip: '새로고침',
                        onPressed: sharedLoading ? null : refreshExplore,
                        icon: const Icon(Icons.refresh_rounded)),
                  ]),
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
                    // 빈 화면에서 바로 공유할 수 있게 한다. 전에는 안내만 있고
                    // 어디서 공유하는지 말하지 않았다(5차 343). 주제로 걸러
                    // 비었으면 공유가 아니라 주제를 되돌리는 게 갈 길이다(500).
                    _SharedMessage(
                        key: const ValueKey('shared-message'),
                        text: sharedSentencesEmptyMessage(
                            category: category, anyShared: shared.isNotEmpty),
                        actionLabel: shared.isEmpty
                            ? shareMySentenceLabel
                            : showAllSentenceTopicsLabel,
                        onAction: shared.isEmpty
                            ? () => showShareMySentenceSheet(context)
                            : () => setState(() => category = allSentenceTopics))
                  else
                    ...visibleShared.map((sentence) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _SentenceCard(
                            sentence: sentence,
                            mine: sentence.authorId == accountId,
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
                  Row(children: [
                    Text('내 문장', style: context.texts.titleLarge),
                    const SizedBox(width: 6),
                    Text('${mySentences.length}',
                        style: context.texts.titleMedium
                            .copyWith(color: colors.onSurfaceVariant)),
                    const Spacer(),
                    // 전에는 "앵무새가 말할 문장 n개" 큰 배너가 따로 있었다.
                    // '앵무새 62'만 적으니 옆의 '내 문장 63'과 무슨 관계인지
                    // 알 수 없었다(5차). 몇 개 중 몇 개인지 함께 적는다.
                    if (mySentences.isNotEmpty)
                      Tooltip(
                        message: '홈 앵무새가 순서대로 말해줘요',
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.record_voice_over_rounded,
                              size: 16, color: colors.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text('앵무새 $routineCount/${mySentences.length}',
                              style: context.texts.labelMedium
                                  .copyWith(color: colors.onSurfaceVariant)),
                        ]),
                      ),
                    IconButton(
                        tooltip: '문장 추가',
                        onPressed: addMySentence,
                        icon: const Icon(Icons.add_rounded)),
                    PopupMenuButton<String>(
                      tooltip: '가져오기·내보내기',
                      icon: const Icon(Icons.more_horiz_rounded),
                      // 메뉴는 가져오기·내보내기 둘뿐이고, 어떤 파일로 할지는
                      // 그다음에 고른다(5차 344, 사용자 요청).
                      onSelected: (value) => switch (value) {
                        'import' => importSentences(),
                        _ => exportSentences(),
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                            value: 'import',
                            child: ListTile(
                                leading: Icon(Icons.file_download_outlined),
                                title: Text('문장 가져오기'))),
                        PopupMenuItem(
                            value: 'export',
                            child: ListTile(
                                leading: Icon(Icons.file_upload_outlined),
                                title: Text('문장 내보내기'))),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 4),
                  ...List.generate(mySentences.length, (index) {
                    final sentence = mySentences[index];
                    return Padding(
                      padding: EdgeInsets.zero,
                      child: _MySentenceTile(
                        sentence: sentence,
                        accountId: accountId,
                        activity:
                            activities[sentence.id] ?? const SentenceActivity(),
                        repository: repository,
                        authorName: authorName,
                        published: publishedIds.contains(sentence.id),
                        swipeKey: _swipeKeys.putIfAbsent(
                            sentence.id, GlobalKey<SwipeActionTileState>.new),
                      ),
                    );
                  }),
                ],
              ])),
            ),
          ],
        ));
  }
}

/// 주소에서 파일을 받는 동안 보여주는 진행 상황.
class _ImportProgress {
  const _ImportProgress(this.label);

  final String label;
}

class _ImportProgressDialog extends StatelessWidget {
  const _ImportProgressDialog({required this.progress});

  final ValueListenable<_ImportProgress> progress;

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        child: AlertDialog(
          key: const ValueKey('import-progress'),
          content: ValueListenableBuilder<_ImportProgress>(
            valueListenable: progress,
            builder: (context, value, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value.label,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                const LinearProgressIndicator(),
              ],
            ),
          ),
        ),
      );
}

class _SentenceCard extends StatelessWidget {
  const _SentenceCard({
    required this.sentence,
    required this.mine,
    required this.saved,
    required this.active,
    required this.onLike,
    required this.onSave,
    required this.onParrot,
    required this.onOpen,
  });

  final SharedSentence sentence;

  /// 보는 사람이 이 문장을 올린 사람인지. 주제 이름을 고를 때 쓴다(5차 337).
  final bool mine;
  final bool saved;
  final bool active;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onParrot;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final topicLabel = sentenceTopicLabel(sentence.topic, mine: mine);
    final muted = context.texts.labelSmall
        .copyWith(color: colors.onSurfaceVariant, fontWeight: FontWeight.w600);
    final author =
        sentence.authorName.trim().isEmpty ? '익명' : sentence.authorName;

    // 어둠에서는 그림자가 안 보여서 카드와 바탕이 붙어 버린다. 어둠에서는
    // 한 톤 밝은 바탕으로, 밝기에서는 흰 바탕에 옅은 그림자로 띄운다(5차 339).
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      key: ValueKey(saved ? 'sentence-card-saved' : 'sentence-card-unsaved'),
      decoration: BoxDecoration(
        color: dark ? colors.surfaceContainerHigh : colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        // 저장한 문장만 테두리로 짚어 준다. 예전에는 배경까지 파랗게 칠해
        // 목록이 알록달록했다(5차 339, 사용자: 카드 모양이 마음에 안 든다).
        border: saved
            ? Border.all(color: colors.primary.withValues(alpha: 0.5))
            : null,
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.07),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 10, 6),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // 누가 언제 올렸는지 먼저. 문장은 그 아래에서 크게 읽힌다.
              Row(children: [
                AuthorAvatar(
                    authorId: sentence.authorId, radius: 12, iconSize: 14),
                const SizedBox(width: 8),
                // 닉네임 · 올린 때를 한 줄로 묶는다. 따로 두니 가운데가 벌어져
                // 줄이 흐트러져 보였다(5차 339, 사용자).
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: author,
                        style: context.texts.bodyMedium.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colors.onSurface),
                      ),
                      TextSpan(text: '  ·  ', style: muted),
                      TextSpan(
                          text: sentenceAgeLabel(
                              sentence.createdAt, DateTime.now()),
                          style: muted),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (saved) ...[
                  Row(
                      key: const ValueKey('saved-chip'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded,
                            size: 13, color: colors.primary),
                        const SizedBox(width: 2),
                        Text('저장됨',
                            style: context.texts.labelSmall.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w700)),
                      ]),
                  const SizedBox(width: 6),
                ],
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color:
                        colors.surfaceContainerHighest.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(topicLabel, style: muted),
                ),
              ]),
              const SizedBox(height: 11),
              // 문장이 카드의 주인공이다. 예전에는 칩과 아이콘에 눌려 작았다.
              Text(sentence.text,
                  style: context.texts.titleLarge
                      .copyWith(fontWeight: FontWeight.w800, height: 1.28)),
              if (sentence.translation.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(sentence.translation,
                    style: context.texts.bodyMedium
                        .copyWith(color: colors.onSurfaceVariant)),
              ],
              const SizedBox(height: 4),
              Row(children: [
                IconButton(
                    tooltip: '좋아요',
                    visualDensity: VisualDensity.compact,
                    iconSize: 19,
                    color: colors.onSurfaceVariant,
                    onPressed: onLike,
                    icon: Icon(
                        sentence.liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border,
                        color: sentence.liked
                            ? context.collectionTokens.liked
                            : null)),
                Text('${sentence.likeCount}', style: muted),
                const SizedBox(width: 12),
                Tooltip(
                  message: importCountTooltip,
                  child: Row(children: [
                    Icon(Icons.download_rounded,
                        size: 17, color: colors.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text('${sentence.importCount}',
                        key: const ValueKey('shared-import-count'),
                        style: muted),
                  ]),
                ),
                const Spacer(),
                IconButton(
                    tooltip: saveToMineTooltip(saved: saved),
                    visualDensity: VisualDensity.compact,
                    iconSize: 20,
                    color: colors.onSurfaceVariant,
                    onPressed: onSave,
                    icon: Icon(
                        saved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        color: saved ? colors.primary : null)),
                IconButton(
                    tooltip: '앵무새에게 보내기',
                    visualDensity: VisualDensity.compact,
                    iconSize: 20,
                    color: colors.onSurfaceVariant,
                    onPressed: onParrot,
                    icon: Icon(Icons.record_voice_over_rounded,
                        color: active
                            ? context.collectionTokens.voiceActive
                            : null)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
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
    showAppSheet<void>(
      context: context,
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
    );

class _MySentenceTile extends StatelessWidget {
  const _MySentenceTile({
    required this.sentence,
    required this.accountId,
    required this.activity,
    required this.repository,
    required this.authorName,
    this.published = false,
    required GlobalKey<SwipeActionTileState> swipeKey,
  }) : _swipeKey = swipeKey;

  final DefaultConversationSentence sentence;
  final String accountId;
  final SentenceActivity activity;
  final SharedSentenceRepository? repository;
  final String authorName;

  /// 지금 둘러보기에 공개 중인지. 목록에서 한눈에 보이게 칩을 붙인다(5차).
  final bool published;

  /// 밀어서 연 동작 칸을 버튼을 누른 뒤 닫으려고 부모가 문장마다 하나씩 준다.
  final GlobalKey<SwipeActionTileState> _swipeKey;

  Future<void> openDetails(BuildContext context) => showSentenceDetails(
        context,
        sentence: sentence,
        accountId: accountId,
        repository: repository,
        authorName: authorName,
      );

  bool get _isMine => sentence.id.startsWith('my-');

  /// 둘러보기에 공유할 수 있는 문장. 상세 시트의 canPublish와 같은 기준.
  bool get _canPublish =>
      _isMine &&
      repository != null &&
      accountId != 'guest' &&
      (sentence.authorId.isEmpty || sentence.authorId == accountId);

  void _toast(BuildContext context, String message) =>
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _toggleRoutine(BuildContext context) async {
    final next = !activity.routineEnabled;
    try {
      await SentenceActivityStore.setRoutineEnabled(
          accountId, sentence.id, next);
      if (context.mounted) {
        _toast(context, next ? '앵무새가 이 문장을 말해요.' : '앵무새 순서에서 뺐어요.');
      }
    } catch (_) {
      if (context.mounted) _toast(context, '루틴 설정을 저장하지 못했어요.');
    }
  }

  /// 공유 중이면 취소를, 아니면 공유를 묻고 처리한다. 문구는 상세 시트와 같다.
  Future<void> _togglePublish(BuildContext context) async {
    final repo = repository!;
    if (authorName.trim().isEmpty) {
      _toast(context, sentenceShareNeedsNickname);
      return;
    }
    bool published;
    try {
      published = await repo.isPublished(sentenceId: sentence.id);
    } catch (_) {
      if (context.mounted) _toast(context, actionFailedMessage);
      return;
    }
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(sentenceShareTitle(published: published)),
        content: Text(
            sentenceShareBody(published: published, authorName: authorName)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(sentenceShareCancelLabel(published: published))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(sentenceShareConfirmLabel(published: published))),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      if (published) {
        await repo.unpublish(sentenceId: sentence.id);
      } else {
        await repo.publish(sentenceId: sentence.id, authorName: authorName);
      }
      if (context.mounted) {
        _toast(context,
            published ? sentenceShareCanceledMessage : sentenceSharedMessage);
      }
    } on ShareLimitReachedException {
      if (context.mounted) {
        _toast(
            context,
            sentenceShareLimitMessage(
                SharedSentenceRepository.dailyShareLimit));
      }
    } catch (_) {
      if (context.mounted) _toast(context, actionFailedMessage);
    }
  }

  Future<void> _remove(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('내 문장에서 지울까요?'),
        content: const Text('지우면 이 문장의 연습 기록과 메모도 더 이상 볼 수 없어요. '
            '둘러보기에 공유 중이었다면 거기서도 사라져요.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('지우기')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await MySentenceStore.remove(accountId, sentence.id);
    } catch (_) {
      if (context.mounted) _toast(context, '지우지 못했어요. 다시 시도해 주세요.');
    }
  }

  Widget _swipeAction(
    BuildContext context, {
    required Color color,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) =>
      Expanded(
        child: Material(
          color: color,
          child: InkWell(
            onTap: () {
              _swipeKey.currentState?.close();
              onTap();
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(height: 2),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        context.texts.labelSmall.copyWith(color: Colors.white)),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final affinity = affinityOf(activity);
    final maxed = affinity.isMax;
    final (_, levelColor) = affinityChipColors(affinity.level);
    // 카드 테두리 없이 줄로 붙인다. 친밀도는 해석 옆의 작은 점과 글자로.
    // 최고 단계만 연한 황금빛 배경을 깐다.
    final row = InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      // 밀어서 동작 칸이 열려 있으면 누를 때 닫기만 한다. 상세는 열지 않는다.
      onTap: () => (_swipeKey.currentState?.isOpen ?? false)
          ? _swipeKey.currentState!.close()
          : openDetails(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(sentence.text,
                        style: context.texts.bodyLarge.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w700)),
                  ),
                  // 공개 중인 문장은 목록에서 바로 알아보게 한다(5차, 사용자 요청).
                  if (published) ...[
                    const SizedBox(width: 6),
                    Container(
                      key: const ValueKey('shared-chip'),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text('공유 중',
                          style: context.texts.labelSmall
                              .copyWith(color: colors.onPrimaryContainer)),
                    ),
                  ],
                ]),
                const SizedBox(height: 3),
                Row(children: [
                  Flexible(
                    child: Text(sentence.translation,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.bodySmall
                            .copyWith(color: colors.onSurfaceVariant)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                        color: levelColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Text('Lv.${affinity.level} ${affinity.name}',
                      style:
                          context.texts.labelSmall.copyWith(color: levelColor)),
                ]),
              ],
            ),
          ),
          // 상세에서 누르는 하트가 저장만 되고 어디에도 안 보였다. 눌러도
          // 달라지는 게 없어서 아무 일도 안 하는 단추처럼 보였다(5차).
          if (activity.liked) ...[
            Tooltip(
              message: '좋아요한 문장',
              child: Icon(Icons.favorite_rounded,
                  key: const ValueKey('sentence-liked-mark'),
                  size: 16,
                  semanticLabel: '좋아요한 문장',
                  color: context.collectionTokens.liked),
            ),
            const SizedBox(width: 6),
          ],
          Icon(Icons.chevron_right_rounded,
              color: colors.onSurface.withValues(alpha: 0.35)),
        ]),
      ),
    );
    final body = !maxed
        ? row
        : Container(
            key: const ValueKey('sentence-card-gold'),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: context.collectionTokens.goldBackground,
              ),
            ),
            child: row,
          );
    final colors2 = Theme.of(context).colorScheme;
    // 밀면 앵무새 켜기/끄기 · 공유 · 삭제. 기본 문장은 앵무새만.
    final actions = <Widget>[
      _swipeAction(context,
          color: colors2.primary,
          icon: activity.routineEnabled
              ? Icons.voice_over_off_rounded
              : Icons.record_voice_over_rounded,
          label: activity.routineEnabled ? '앵무새 끄기' : '앵무새 켜기',
          onTap: () => _toggleRoutine(context)),
      if (_canPublish)
        _swipeAction(context,
            color: colors2.tertiary,
            icon: Icons.public_rounded,
            label: '공유',
            onTap: () => _togglePublish(context)),
      if (_isMine)
        _swipeAction(context,
            color: colors2.error,
            icon: Icons.delete_outline_rounded,
            label: '지우기',
            onTap: () => _remove(context)),
    ];
    return SwipeActionTile(
      key: _swipeKey,
      actionWidth: swipeActionSlotWidth * actions.length,
      actions: actions,
      child: body,
    );
  }
}

/// 문장 탭 맨 위의 둘러보기 한 줄. 좋아요가 많은 공유 문장 몇 개와 "전체".
class _ExploreStrip extends StatelessWidget {
  const _ExploreStrip({
    required this.sentences,
    required this.accountId,
    required this.loading,
    required this.failed,
    required this.onOpen,
    required this.onViewAll,
    required this.onRetry,
    required this.emptyMessage,
  });

  final List<SharedSentence> sentences;

  /// 보는 사람. 올린 사람과 같으면 '내 문장'이라 적는다(5차 337).
  final String accountId;
  final bool loading;
  final bool failed;
  final ValueChanged<SharedSentence> onOpen;
  final VoidCallback onViewAll;

  /// 못 불러왔을 때 다시 불러온다. 아래 목록에는 있던 길이 여기엔 없었다(5차 394).
  final VoidCallback onRetry;

  /// 보일 게 없을 때 할 말. 주제로 걸러 빈 것인지까지 가려서 받는다(5차 500).
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted =
        context.texts.bodySmall.copyWith(color: colors.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          // 홈에서는 같은 것을 '공유 문장'이라 부른다. 홈의 '전체 보기'로
          // 오면 제목이 달라 다른 곳처럼 보였다(5차).
          Text('공유 문장 둘러보기', style: context.texts.titleLarge),
          const Spacer(),
          // 볼 문장이 없는데도 '전체 보기'가 있어서 누르면 빈 화면만 열렸다(5차).
          if (loading || (!failed && sentences.isNotEmpty))
            TextButton(
              key: const ValueKey('open-explore'),
              onPressed: onViewAll,
              // 바로 위 카테고리 칩 '전체'와 같은 말이라 헷갈렸다. 홈과 같은 말로(5차).
              child: const Text('전체 보기'),
            ),
        ]),
        const SizedBox(height: 6),
        if (loading)
          const SizedBox(
              height: 92,
              child: Center(
                  child: SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4))))
        else if (failed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Expanded(child: Text('공유된 문장을 불러오지 못했어요.', style: muted)),
              TextButton(
                key: const ValueKey('explore-strip-retry'),
                onPressed: onRetry,
                child: const Text('다시 불러오기'),
              ),
            ]),
          )
        else if (sentences.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(emptyMessage, style: muted),
          )
        else
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: sentences.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = sentences[index];
                final mine = item.authorId == accountId;
                // 아래 목록 카드와 같은 결로(5차 339). 이 작은 카드는 닉네임
                // 줄이 아래에 있고, 주제는 목록 카드에서 본다.
                final who = mine
                    ? myOwnSentenceTopic
                    : (item.authorName.trim().isEmpty
                        ? sharedSentenceTopic
                        : item.authorName);
                return Material(
                  color: dark
                      ? colors.surfaceContainerHigh
                      : colors.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    onTap: () => onOpen(item),
                    child: Container(
                      width: 228,
                      padding: const EdgeInsets.fromLTRB(13, 11, 13, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.texts.bodyLarge.copyWith(
                                  color: colors.onSurface,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(item.translation,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: muted),
                          const Spacer(),
                          Row(children: [
                            AuthorAvatar(
                                authorId: item.authorId,
                                radius: 10,
                                iconSize: 12),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(who,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.texts.labelSmall.copyWith(
                                      color: colors.onSurfaceVariant,
                                      fontWeight: FontWeight.w700)),
                            ),
                            Icon(
                                item.liked
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                size: 14,
                                color: item.liked
                                    ? context.collectionTokens.liked
                                    : colors.onSurfaceVariant),
                            const SizedBox(width: 3),
                            Text('${item.likeCount}',
                                style: context.texts.labelSmall
                                    .copyWith(color: colors.onSurfaceVariant)),
                          ]),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// 저장한 문장을 고치는 창(5차, 사용자 요청).
///
/// 전에는 고치는 길이 아예 없어서, 오타 하나를 고치려면 지우고 다시 넣어야
/// 했다. 그러면 연습 기록과 친밀도가 함께 사라졌다.
class SentenceEditDialog extends StatefulWidget {
  const SentenceEditDialog({super.key, required this.sentence, this.assist});

  final DefaultConversationSentence sentence;

  /// 빈 칸을 채워 줄 곳. 테스트에서 끼워 넣는다.
  final SentenceAssist? assist;

  @override
  State<SentenceEditDialog> createState() => _SentenceEditDialogState();
}

class _SentenceEditDialogState extends State<SentenceEditDialog> {
  late final _text = TextEditingController(text: widget.sentence.text);
  late final _pron = TextEditingController(text: widget.sentence.pronunciation);
  late final _meaning =
      TextEditingController(text: widget.sentence.translation);
  String? _hint;

  /// 한도 조회는 앱에 하나 있는 것을 받아 쓴다(5차 564).
  late final SentenceAssist _assist = widget.assist ??
      context.read<CloudSentenceAssist?>() ??
      const UnavailableSentenceAssist();

  bool _filling = false;

  /// 이미 받아 둔 숫자가 있으면 기다리지 않는다(5차 565).
  late bool _usageLoading = _assist.dailyLimit == null;
  late bool _usageChecked = _assist.dailyLimit != null;

  /// 서버가 채워 준 결과나 막힌 까닭.
  String? _fillNote;

  int? get _assistUsed => assistUsedToday(
        limit: _assist.dailyLimit,
        remaining: _assist.remainingToday,
        credits: _assist.assistCredits ?? 0,
      );

  bool get _exhausted =>
      _usageChecked &&
      assistExhausted(
        used: _assistUsed,
        limit: _assist.dailyLimit,
        credits: _assist.assistCredits ?? 0,
      );

  List<String> get _fields =>
      [_text.text.trim(), _pron.text.trim(), _meaning.text.trim()];

  /// 채울 빈 칸이 있고, 맞출 거리가 하나라도 있는지.
  ///
  /// 문장 추가 화면과 달리 여기 적힌 것은 이미 한 문장에서 온 값이라 서로
  /// 다툴 일이 없다. 그래서 두 칸이 차 있어도 남은 한 칸을 채워 준다 -
  /// 발음만 비어 있는 문장이 흔하다(5차 565, 사용자 요청).
  bool get _hasBlank => _fields.any((f) => f.isEmpty);
  bool get _hasSource => _fields.any((f) => f.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _assist.refreshUsage().whenComplete(() {
      if (mounted) {
        setState(() {
          _usageChecked = true;
          _usageLoading = false;
        });
      }
    });
  }

  /// 빈 칸을 서버에 물어 채운다. 문장 추가의 그 단추와 같은 일을 한다.
  Future<void> _fillBasics() async {
    if (_filling) return;
    setState(() {
      _filling = true;
      _fillNote = null;
      _hint = null;
    });
    try {
      final filled = await _assist.complete(
        language: widget.sentence.language,
        text: _text.text.trim(),
        translation: _meaning.text.trim(),
        pronunciation: _pron.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        if (_text.text.trim().isEmpty && (filled.text ?? '').isNotEmpty) {
          _text.text = filled.text!;
        }
        if (_meaning.text.trim().isEmpty &&
            (filled.translation ?? '').isNotEmpty) {
          _meaning.text = filled.translation!;
        }
        if (_pron.text.trim().isEmpty &&
            (filled.pronunciation ?? '').isNotEmpty) {
          _pron.text = filled.pronunciation!;
        }
      });
    } on SentenceAssistQuotaExceeded {
      if (mounted) setState(() => _fillNote = assistQuotaExhaustedMessage);
    } on SentenceAssistUnavailable catch (e) {
      if (mounted) setState(() => _fillNote = e.reason);
    } catch (_) {
      if (mounted) setState(() => _fillNote = actionFailedMessage);
    } finally {
      if (mounted) setState(() => _filling = false);
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _pron.dispose();
    _meaning.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = sentenceEditBlockedReason(
      text: _text.text,
      before: widget.sentence,
      pronunciation: _pron.text,
      translation: _meaning.text,
    );
    if (reason != null) {
      setState(() => _hint = reason);
      return;
    }
    Navigator.pop(context, (
      text: _text.text.trim(),
      pronunciation: _pron.text.trim(),
      translation: _meaning.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      // 단어 시트와 같은 꼴로 둔다(5차 565, 사용자 요청). 테두리를 없애고
      // 면으로 칸을 그리고, 꼭 적어야 하는 칸만 별표를 단다.
      title: Row(
        children: [
          const Expanded(child: Text('문장 고치기')),
          AssistUsagePair(
            kind: AssistKind.meaning,
            used: _assistUsed,
            limit: _assist.dailyLimit,
            credits: _assist.assistCredits ?? 0,
            key: const ValueKey('edit-sentence-usage'),
          ),
        ],
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const ValueKey('edit-sentence-text'),
                controller: _text,
                autofocus: true,
                maxLines: 4,
                minLines: 1,
                onChanged: (_) => setState(() => _hint = null),
                decoration: filledInputDecoration(context,
                    label: requiredFieldLabel('문장')),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: const ValueKey('edit-sentence-pron'),
                controller: _pron,
                onChanged: (_) => setState(() => _hint = null),
                decoration: filledInputDecoration(
                  context,
                  label: wordPronunciationLabel,
                  hint: '한글로 소리 나는 대로',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: const ValueKey('edit-sentence-meaning'),
                controller: _meaning,
                maxLines: 3,
                minLines: 1,
                onChanged: (_) => setState(() => _hint = null),
                decoration:
                    filledInputDecoration(context, label: wordMeaningLabel),
              ),
              // 빈 칸은 서버가 채워 줄 수 있다(5차 565, 사용자 요청).
              // 문장 추가의 그 단추와 같은 일을 한다.
              const SizedBox(height: AppSpacing.md),
              FilledButton.tonalIcon(
                key: const ValueKey('edit-sentence-fill'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
                onPressed: _filling ||
                        _usageLoading ||
                        _exhausted ||
                        !_hasBlank ||
                        !_hasSource
                    ? null
                    : _fillBasics,
                icon: _filling
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const AssistIcon(AssistKind.meaning, size: 18),
                label: const Text(fillBasicsLabel),
              ),
              const SizedBox(height: AppSpacing.xs + 2),
              Text(
                assistFillHint(
                  loading: _usageLoading,
                  whenReady: _exhausted
                      ? assistQuotaExhaustedMessage
                      : !_hasSource
                          ? fillNeedsAnyFieldHint
                          : !_hasBlank
                              ? fillNothingLeftMessage
                              : fillNeedsAnyFieldHint,
                ),
                key: const ValueKey('edit-sentence-fill-hint'),
                style:
                    context.texts.bodySmall.copyWith(color: cs.onSurfaceVariant),
              ),
              if (_fillNote case final note?) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  note,
                  key: const ValueKey('edit-sentence-fill-note'),
                  style: context.texts.bodySmall.copyWith(color: cs.error),
                ),
              ],
              // 막힌 까닭은 띠로 적는다. 전에는 회색 한 줄이라 안 보였다.
              if (_hint case final hint?) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 16, color: cs.onErrorContainer),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          hint,
                          key: const ValueKey('edit-sentence-hint'),
                          style: context.texts.bodySmall
                              .copyWith(color: cs.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          key: const ValueKey('save-sentence-edit'),
          // 꺼진 채 두지 않고 까닭을 적는다(5차).
          onPressed: _submit,
          child: const Text('저장'),
        ),
      ],
    );
  }
}

/// 고칠 수 없는 까닭. 없으면 null.
String? sentenceEditBlockedReason({
  required String text,
  required DefaultConversationSentence before,
  String pronunciation = '',
  String translation = '',
}) {
  if (text.trim().isEmpty) return sentenceNeededMessage;
  final same = text.trim() == before.text.trim() &&
      pronunciation.trim() == before.pronunciation.trim() &&
      translation.trim() == before.translation.trim();
  if (same) return noChangesMessage;
  return null;
}

/// 고른 낱말과 같거나 어형만 다른 단어가 단어장에 있을 때 묻는 창
/// (5차, 사용자 요청). 어느 단어에 붙일지 고르거나, 새로 만든다.
class _SameWordDialog extends StatelessWidget {
  const _SameWordDialog({required this.picked, required this.candidates});

  final String picked;

  /// 같은 낱말이 먼저, 그다음 어형만 다른 것들.
  final List<MyWord> candidates;

  bool get _exactOnly =>
      candidates.length == 1 &&
      candidates.first.word.trim().toLowerCase() == picked.trim().toLowerCase();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      key: const ValueKey('same-word-dialog'),
      title: Text(
          _exactOnly ? "'$picked'이(가) 이미 있어요" : "'$picked'과(와) 비슷한 단어가 있어요"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _exactOnly ? '이 문장을 예문으로 더할까요?' : '어느 단어에 이 문장을 예문으로 더할까요?',
            style: context.texts.bodyMedium
                .copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          for (final word in candidates)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: OutlinedButton(
                key: ValueKey('same-word-pick-${word.id}'),
                onPressed: () => Navigator.pop(context, word),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  alignment: Alignment.centerLeft,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        word.meaning.trim().isEmpty
                            ? word.word
                            : '${word.word} · ${word.meaning}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text('예문 ${word.examples.length}',
                        style: context.texts.labelSmall
                            .copyWith(color: colors.onSurfaceVariant)),
                  ],
                ),
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
          key: const ValueKey('same-word-add-new'),
          onPressed: () => Navigator.pop(context, _addNewWord),
          child: Text("'$picked' 새로 만들기"),
        ),
      ],
    );
  }
}

/// '새로 만들기'를 골랐다는 표시.
const Object _addNewWord = Object();

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

  /// 시트 안에 적는 알림. 토스트·스낵바는 시트 뒤에 깔려 보이지 않는다(5차 390).
  String? notice;
  Timer? noticeTimer;
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

  /// 따라 말하기. 홈 무대와 같은 위젯·기록·XP를 쓴다(5차).
  final PhraseRecognizer recognizer = SpeechToTextRecognizer();

  /// 마지막 연습 점수(100점 만점). 아직 안 했으면 null.
  int? lastPracticeScore;

  /// 따라 말하기를 시작할 때 읽어 주던 소리를 멈추려고 들고 있는다.
  final GlobalKey speakControlsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    memoFocus.addListener(saveMemo);
    loadActivity();
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

  /// 시트 안에 한 줄 알린다. 잠시 뒤 스스로 사라지고, 누르면 바로 사라진다.
  void showNotice(String message) {
    if (!mounted) return;
    setState(() => notice = message);
    noticeTimer?.cancel();
    noticeTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => notice = null);
    });
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
    if (widget.accountId == 'guest') {
      showNotice(sentenceShareNeedsLogin);
      return;
    }
    if (published == true) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          key: const ValueKey('unpublish-dialog'),
          title: Text(sentenceShareTitle(published: true)),
          content: Text(sentenceShareBody(published: true, authorName: '')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(sentenceShareCancelLabel(published: true))),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(sentenceShareConfirmLabel(published: true))),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    if (published != true) {
      if (widget.authorName.trim().isEmpty) {
        showNotice(sentenceShareNeedsNickname);
        return;
      }
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(sentenceShareTitle(published: false)),
          content: Text(sentenceShareBody(
              published: false, authorName: widget.authorName)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(sentenceShareCancelLabel(published: false))),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(sentenceShareConfirmLabel(published: false))),
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
      showNotice(next ? sentenceSharedMessage : sentenceShareCanceledMessage);
    } on ShareLimitReachedException {
      showNotice(
          sentenceShareLimitMessage(SharedSentenceRepository.dailyShareLimit));
    } catch (_) {
      showNotice(actionFailedMessage);
    } finally {
      if (mounted) setState(() => publishing = false);
    }
  }

  /// 마이크 버튼: 이 문장을 TTS로 읽어준다. 읽는 중에 다시 누르면 멈춘다.
  /// 따라 말하기 시도 하나를 기록에 남긴다(홈 무대와 같은 저장소).
  void recordPracticeAttempt(PracticeAttemptResult result) {
    setState(() {
      lastPracticeScore =
          result.score == null ? null : (result.score! * 100).round();
    });
    unawaited(PracticeLogStore.add(
      widget.accountId,
      PracticeAttempt(
        at: DateTime.now(),
        sentenceId: widget.sentence.id,
        score: result.score,
        heard: result.heard,
        success: result.success,
        manual: result.manual,
        durationMs: result.duration.inMilliseconds,
      ),
    ).catchError((Object _) {/* 기록 실패가 연습을 막지는 않는다. */}));
  }

  /// 한 번 따라 말하기를 마쳤다. 연습 수를 올리고 XP를 더한다.
  Future<void> completePractice(double? score) async {
    // 따라 말하기 자리는 내 문장일 때만 보이지만, 기록을 쌓는 쪽에서도
    // 한 번 더 따진다. 듣기도 같은 자리를 빠뜨려 새어 나갔다(5차 410).
    if (!widget.saved) return;
    await SentenceActivityStore.incrementPractice(
      widget.accountId,
      widget.sentence.id,
      score: score,
    );
    final total = await addSpeakingXp(widget.accountId, score);
    // 홈 '학습 캘린더'에도 쌓는다. 전에는 홈 무대에서 한 것만 쌓여,
    // 바로 위 '내 문장 기록'과 어긋나 보였다(5차).
    await PracticeCalendar.recordOne(widget.accountId);
    if (!mounted) return;
    // 따라 말하기 한 번에 크래커를 뽑아 준다. 상한에 걸리면 0이고, 그러면
    // 알리지 않는다(연습 자체는 막지 않는다)(5차 505).
    final reward = await grantPracticeReward(context, widget.accountId);
    if (!mounted) return;
    final scoreText = score == null ? '' : '${(score * 100).round()}점 · ';
    final rewardText =
        reward.isEmpty ? '' : ' · ${practiceRewardEarned(reward.crackers)}';
    showNotice(total == null
        ? '따라 말하기 완료 · $scoreText기록했어요$rewardText'
        : '따라 말하기 완료 · $scoreText+${xpText(xpGain(score))} XP$rewardText');
    await loadActivity();
  }

  @override
  void dispose() {
    memoTimer?.cancel();
    noticeTimer?.cancel();
    memoFocus.removeListener(saveMemo);
    // 시트를 바로 닫아도 쓰던 메모가 사라지지 않게 마지막으로 저장한다.
    saveMemo();
    memoController.dispose();
    memoFocus.dispose();
    super.dispose();
  }

  /// 문장을 고친다. 내 문장일 때만 보인다.
  Future<void> editSentence() async {
    // 시트를 닫고 알리므로 스낵바가 보인다
    final messenger = ScaffoldMessenger.of(context);
    final next = await showDialog<
        ({String text, String pronunciation, String translation})>(
      context: context,
      builder: (_) => SentenceEditDialog(sentence: widget.sentence),
    );
    if (!mounted || next == null) return;

    final saved = await MySentenceStore.update(
      widget.accountId,
      widget.sentence.id,
      text: next.text,
      pronunciation: next.pronunciation,
      translation: next.translation,
    );
    if (!mounted) return;
    if (!saved) {
      showNotice('고치지 못했어요. 같은 문장이 이미 있는지 확인해 주세요.');
      return;
    }
    // 시트를 닫고 알리므로 스낵바가 보인다
    messenger.showSnackBar(const SnackBar(content: Text('문장을 고쳤어요.')));
    // 고친 내용으로 목록과 앵무새가 다시 읽도록, 창을 닫는다.
    if (mounted) Navigator.pop(context);
  }

  /// 끝까지 들은 것을 기록한다. 실패해도 소리 흐름은 건드리지 않는다.
  ///
  /// **내 문장일 때만 센다**(5차 410, 사용자 신고). 둘러보기에서 남의 문장을
  /// 듣기만 해도 그 문장의 듣기 수가 쌓여 친밀도가 올라갔다. 아래 기록
  /// 칸과 따라 말하기는 이미 내 문장일 때만 보이는데 듣기만 새어 나갔다.
  void countListen() {
    if (!widget.saved) return;
    unawaited(SentenceActivityStore.incrementListen(
      widget.accountId,
      widget.sentence.id,
    ).then((_) {
      if (mounted) loadActivity();
    }).catchError((Object _) {}));
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
        showNotice('루틴 설정을 저장하지 못했어요.');
      }
    } finally {
      if (mounted) setState(() => changingRoutine = false);
    }
  }

  Future<void> removeSentence() async {
    final navigator = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('delete-dialog'),
        title: const Text('내 문장에서 지울까요?'),
        content: Text(published == true
            ? '지금 둘러보기에 공유 중인 문장이에요. 지우면 둘러보기에서도 사라지고 '
                '좋아요 수와 가져간 수도 함께 사라져요.\n이미 가져간 사람의 문장은 그대로 남아요.'
            : '지우면 이 문장의 연습 기록과 메모도 더 이상 볼 수 없어요.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('지우기')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await MySentenceStore.remove(widget.accountId, widget.sentence.id);
      navigator.pop();
    } catch (_) {
      showNotice('지우지 못했어요. 다시 시도해 주세요.');
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
          showNotice(likeFailedMessage);
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
      showNotice(likeFailedMessage);
    }
  }

  /// 이 문장의 단어를 내 단어로 저장한다. 문장이 예문으로 붙는다(5차 6번).
  /// [word]가 비어 있으면 직접 입력.
  Future<void> saveWord(String word) async {
    // 'projections'를 골랐는데 단어장에 'projection'이 있으면, 어느 단어에
    // 붙일지 묻는다. 자동으로 바꾸지 않는다(5차, 사용자 요청).
    final related = await MyWordStore.findRelatedWords(
      widget.accountId,
      language: widget.sentence.language,
      word: word,
    );
    if (!mounted) return;
    if (related.isNotEmpty) {
      final choice = await showDialog<Object>(
        context: context,
        builder: (_) => _SameWordDialog(picked: word, candidates: related),
      );
      if (!mounted || choice == null) return;
      if (choice is MyWord) {
        final added = await MyWordStore.addExample(
          widget.accountId,
          choice.id,
          WordExample(
            text: widget.sentence.text,
            translation: widget.sentence.translation,
            sourceSentenceId: widget.sentence.id,
          ),
        );
        if (!mounted) return;
        showNotice(added ? "'${choice.word}'에 예문을 더했어요." : '이미 같은 예문이 있어요.');
        return;
      }
    }

    final result = await showAppSheet(
      context: context,
      builder: (_) => AddWordSheet(
        accountId: widget.accountId,
        language: widget.sentence.language,
        initialWord: word,
        example: widget.sentence.text,
        exampleTranslation: widget.sentence.translation,
        sourceSentenceId: widget.sentence.id,
      ),
    );
    if (!mounted || result == null) return;
    showNotice(wordAddResultText(result));
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
    // 주제를 고르지 않은 남의 문장에는 주제를 붙이지 않는다(5차 338).
    final headerTopic = sentenceTopicLabel(
      widget.sentence.topic,
      mine:
          widget.shared == null || widget.shared!.authorId == widget.accountId,
    );
    final sheetNotice = notice;
    return Stack(
      children: [
        SingleChildScrollView(
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                    ),
                    child: Text(
                      '${widget.sentence.language} · $headerTopic',
                      style: context.texts.labelSmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 친밀도는 내 문장에만 쌓인다. 저장하지 않은 남의 문장에
                  // 'Lv.1 낯선'이 뜨면 내 기록처럼 보인다(5차 410).
                  if (widget.saved)
                    _MasteryBadge(
                        mastery: masteryOf(activity),
                        affinity: affinityOf(activity)),
                  const Spacer(),
                  IconButton(
                    key: const ValueKey('like-sentence'),
                    tooltip: liked ? '좋아요 취소' : '좋아요',
                    onPressed:
                        loading && widget.shared == null ? null : toggleLike,
                    icon: Icon(
                      liked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: liked ? context.collectionTokens.liked : null,
                    ),
                  ),
                  if (widget.shared != null) ...[
                    Text('$sharedLikes', style: context.texts.bodySmall),
                    const SizedBox(width: 12),
                    // 숫자만 있으면 무슨 수인지 알 수 없다(5차 458).
                    Tooltip(
                      message: importCountTooltip,
                      child: Row(children: [
                        Icon(Icons.download_rounded,
                            size: 18, color: colors.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Text('$sharedImports',
                            key: const ValueKey('detail-import-count'),
                            style: context.texts.bodySmall),
                      ]),
                    ),
                  ],
                  // 내가 저장한 문장만 고칠 수 있다(5차, 사용자 요청).
                  if (widget.saved && widget.shared == null)
                    IconButton(
                      key: const ValueKey('edit-sentence'),
                      tooltip: '문장 고치기',
                      onPressed: editSentence,
                      icon: const Icon(Icons.edit_outlined),
                    ),
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
                      style:
                          context.texts.headlineMedium.copyWith(height: 1.25),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 듣기·반복 듣기는 단어 상세와 같은 위젯을 쓴다(5차 320).
                  SpeakControls(
                    key: speakControlsKey,
                    text: widget.sentence.text,
                    language: widget.sentence.language,
                    speakKey: const ValueKey('speak-sentence'),
                    repeatKey: const ValueKey('repeat-sentence'),
                    // 끝까지 들으면 '듣기 N회'에 적는다. 홈 무대만 세고 있어서
                    // 여기서 들으면 0회 그대로였다(5차 338, 사용자 신고).
                    onListened: countListen,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.sentence.pronunciation,
                style: context.texts.bodyMedium.copyWith(color: colors.primary),
              ),
              const SizedBox(height: 5),
              Text(
                widget.sentence.translation,
                style: context.texts.bodyLarge
                    .copyWith(color: colors.onSurfaceVariant),
              ),
              if (widget.sentence.author.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  key: const ValueKey('sentence-author'),
                  children: [
                    // 올린 사람 프로필 사진. 없으면 사람 아이콘(5차 338, 사용자 요청).
                    AuthorAvatar(
                        authorId:
                            widget.shared?.authorId ?? widget.sentence.authorId,
                        radius: 11,
                        iconSize: 14),
                    const SizedBox(width: 6),
                    Text(
                      widget.sentence.author,
                      style: context.texts.labelMedium
                          .copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              _WordPickRow(
                sentence: widget.sentence,
                onPick: saveWord,
              ),
              // 내 기록은 내 문장일 때만 보인다. 저장하지 않은 남의 문장에는 보이지 않는다.
              if (widget.saved) ...[
                const SizedBox(height: 18),
                // 위에도 문장이 있어서, 아래 줄이 '연습하는 자리'라는 것을
                // 이름으로 알린다(5차).
                Row(
                  children: [
                    Icon(Icons.mic_rounded, size: 16, color: colors.primary),
                    const SizedBox(width: 6),
                    Text('따라 말하기',
                        style: context.texts.labelLarge
                            .copyWith(color: colors.onSurface)),
                  ],
                ),
                const SizedBox(height: 8),
                SpeechPracticeView(
                  key: const ValueKey('sentence-speech-practice'),
                  phrase: widget.sentence.text,
                  localeId: _ttsLocales[widget.sentence.language] ?? 'en-US',
                  recognizer: recognizer,
                  enabled: true,
                  reduceMotion: MediaQuery.disableAnimationsOf(context),
                  onBeforeStart: () => unawaited(AudioFocus.instance.claim()),
                  onAttempt: recordPracticeAttempt,
                  onComplete: (score) => unawaited(completePractice(score)),
                ),
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
                        // 홈 '내 문장 기록'과 같은 말·단위로(5차). 예전 '0번 내가 들음'.
                        label: '듣기',
                        count: activity.listenCount,
                        loading: loading,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActivityCountCard(
                        icon: Icons.mic_rounded,
                        label: '따라 말하기',
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
                      ? '아직 따라 말해 보지 않았어요'
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
                  // 테두리 없는 면으로(5차 565, 사용자 요청). 글자 수는
                  // 한도에 가까워졌을 때만 적는다.
                  buildCounter: nearLimitCounter,
                  decoration: filledInputDecoration(
                    context,
                    label: '메모',
                    hint: '이 문장에 대한 메모를 남겨 보세요',
                    showCounter: true,
                  ).copyWith(alignLabelWithHint: true),
                ),
              ],
              const SizedBox(height: 14),
              ClipSentenceMatchesSection(sentence: widget.sentence.text),
              const SizedBox(height: 10),
              if (!widget.saved &&
                  widget.shared != null &&
                  widget.onSaveShared != null) ...[
                // 위 숫자가 무엇을 센 것인지 여기서 말로 적는다(5차 458).
                if (importedByLabel(sharedImports) != null) ...[
                  Text(
                    importedByLabel(sharedImports)!,
                    key: const ValueKey('detail-import-line'),
                    style: context.texts.bodySmall
                        .copyWith(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 6),
                ],
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
                  label: const Text('내 문장에서 지우기'),
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
                  style: context.texts.bodySmall
                      .copyWith(color: colors.onSurfaceVariant),
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
        ),
        // 시트 안에 띄운다. 스낵바·토스트는 시트 뒤에 깔려 보이지 않는다(5차 390).
        if (sheetNotice != null)
          Positioned(
            left: 16,
            right: 16,
            // 아래가 아니라 위에 띄운다. 아래에 두면 '둘러보기에 공유하기'
            // 같은 시트 맨 밑 버튼을 가린다(5차 390).
            top: 4,
            child: GestureDetector(
              onTap: () {
                noticeTimer?.cancel();
                setState(() => notice = null);
              },
              child: Material(
                color: colors.inverseSurface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  child: Text(
                    sheetNotice,
                    key: const ValueKey('sentence-detail-notice'),
                    style: context.texts.bodyMedium
                        .copyWith(color: colors.onInverseSurface),
                  ),
                ),
              ),
            ),
          ),
      ],
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
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colors.primary),
          const SizedBox(height: 12),
          Text(
            loading ? '—' : '$count회',
            style: context.texts.headlineSmall,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: context.texts.labelSmall
                .copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
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
            style: context.texts.labelMedium
                .copyWith(color: colors.onSurfaceVariant)),
        const SizedBox(width: 8),
        Expanded(
          child: Text('공유해도 공개되지 않아요',
              style: context.texts.labelSmall
                  .copyWith(color: colors.onSurfaceVariant)),
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
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        SvgPicture.asset(
            'assets/badges/affinity_${affinity.level.clamp(1, SentenceAffinity.maxLevel)}.svg',
            width: 18,
            height: 18),
        const SizedBox(width: 3),
        Text(
          'Lv.${affinity.level} ${affinity.name}',
          style: context.texts.labelSmall.copyWith(color: foreground),
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
        Text(text, style: context.texts.bodySmall.copyWith(color: color)),
      ]),
    );
  }
}

class _WordPickRow extends StatelessWidget {
  const _WordPickRow({required this.sentence, required this.onPick});

  final DefaultConversationSentence sentence;
  final ValueChanged<String> onPick;

  static final _edge =
      RegExp(r"^[^\p{L}\p{N}]+|[^\p{L}\p{N}'’]+$", unicode: true);

  List<String> get tokens {
    final seen = <String>{};
    final out = <String>[];
    for (final raw in sentence.text.split(RegExp(r'\s+'))) {
      final token = raw.replaceAll(_edge, '');
      if (token.isEmpty || token.length == sentence.text.trim().length) {
        continue;
      }
      if (seen.add(token.toLowerCase())) out.add(token);
      if (out.length >= 12) break;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      key: const ValueKey('word-pick-row'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('단어 저장',
            style: context.texts.labelMedium
                .copyWith(color: colors.onSurfaceVariant)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final token in tokens)
              ActionChip(
                key: ValueKey('pick-word-$token'),
                label: Text(token),
                visualDensity: VisualDensity.compact,
                onPressed: () => onPick(token),
              ),
            ActionChip(
              key: const ValueKey('pick-word-custom'),
              avatar: const Icon(Icons.add_rounded, size: 16),
              // 단어 탭 칩과 같은 말로(5차). 예전 '직접 입력'.
              label: const Text('직접 추가'),
              visualDensity: VisualDensity.compact,
              onPressed: () => onPick(''),
            ),
          ],
        ),
      ],
    );
  }
}
