import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parrokit/core/content/add_sentence_controller.dart';
import 'package:parrokit/core/content/default_conversation_sentences.dart';
import 'package:parrokit/core/content/learning_languages.dart';
import 'package:parrokit/core/content/my_sentence_store.dart';
import 'package:parrokit/core/content/practice_log.dart';
import 'package:parrokit/core/content/sentence_activity_store.dart';
import 'package:parrokit/core/content/sentence_mastery.dart';
import 'package:parrokit/core/shared/widgets/learning_language_picker.dart';
import 'package:parrokit/core/shared/widgets/sentence_affinity_bar.dart';
import 'package:parrokit/core/speech/phrase_recognizer.dart';
import 'package:parrokit/core/speech/speech_match.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/sentence_collection_preview.dart'
    show showSentenceDetails;
import 'add_sentence_screen.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'nest_preview.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';

enum _SpeakingMode { automatic, repeat }

/// 다음 문장을 고르는 방식. 버튼을 누를 때마다 순서대로 → 하나 반복 → 랜덤 순으로 바뀐다.
enum _PlayOrder {
  sequential('순서대로', Icons.repeat_rounded),
  repeatOne('하나 반복', Icons.repeat_one_rounded),
  shuffle('랜덤', Icons.shuffle_rounded);

  const _PlayOrder(this.label, this.icon);
  final String label;
  final IconData icon;

  _PlayOrder get next => values[(index + 1) % values.length];
}

/// 앵무새의 자동 말하기와 따라 말하기 무대.
/// 홈([CharacterDashboardScreen])이 `embedded: true`로 맨 위에 품는다.
/// 기존 경로 호환을 위해 화면 이름은 유지한다.
class StagePreviewScreen extends StatefulWidget {
  const StagePreviewScreen(
      {super.key,
      this.embedded = false,
      this.language = '영어',
      this.nickname = '나',
      this.accountId = 'guest',
      this.recognizer,
      this.onPracticeCompleted});
  final String nickname;
  final String accountId;
  final bool embedded;
  final String language;
  final Future<void> Function()? onPracticeCompleted;

  /// 따라 말하기 음성 인식. 비우면 기기 음성 인식을 쓴다.
  final PhraseRecognizer? recognizer;
  @override
  State<StagePreviewScreen> createState() => _StagePreviewScreenState();
}

class _StagePreviewScreenState extends State<StagePreviewScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final animation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
      animationBehavior: AnimationBehavior.preserve)
    ..addStatusListener(onSpeechStatus)
    ..addListener(onBubbleTick);
  late final birdAnimation =
      AnimationController(vsync: this, duration: const Duration(seconds: 12));
  ui.Image? nestSprite;
  _SpeakingMode mode = _SpeakingMode.automatic;
  bool paused = false;
  bool foreground = true;
  bool visible = true;
  bool reduceMotion = false;
  bool awaitingResponse = false;
  bool completingResponse = false;
  bool soundOn = true;

  /// 하단 "반복 듣기" 아이콘이 켜져 있을 때만 앵무새가 소리 내어 말한다.
  bool listenMode = false;
  final FlutterTts tts = FlutterTts();
  late final PhraseRecognizer recognizer =
      widget.recognizer ?? SpeechToTextRecognizer();
  static const _speechLocales = {'영어': 'en_US', '일본어': 'ja_JP', '중국어': 'zh_CN'};
  bool ttsReady = false;
  bool ttsSpeaking = false;
  bool pendingAdvance = false;

  /// 앵무새가 문장을 다 말한 뒤 다음 문장으로 넘어가기 전에 쉬는 간격. 설정에서 바꾼다.
  /// 자동 모드에서만 쓰고, 따라 말하기 모드는 [_repeatGap]을 쓴다.
  static const _defaultGapSeconds = 1.5;
  double gapSeconds = _defaultGapSeconds;

  /// 따라 말하기 모드에서 앵무새가 말을 마친 뒤 내 차례(말하기 창)가 뜨기까지의 간격. 설정 없이 고정이다.
  static const _repeatGap = Duration(milliseconds: 800);

  /// 끄면 앵무새 음성을 끝까지 들어도 들은 횟수를 올리지 않는다.
  bool countListen = true;
  Duration get _phraseGap => mode == _SpeakingMode.repeat
      ? _repeatGap
      : Duration(milliseconds: (gapSeconds * 1000).round());
  Timer? gapTimer;
  bool gapWaiting = false;

  /// 음성 진행(읽은 위치)에 맞춰 말풍선 글자를 보여주는 상태.
  /// 단어 단위로 오는 진행 값을 짧게 보간해 한 글자씩 나오는 것처럼 보이게 한다.
  bool voiceTyping = false;

  /// 지금 음성으로 읽고 있는 문장 id. 끝까지 들으면 청취 횟수를 올린다.
  String? speakingSentenceId;
  double typedFrom = 0;
  double typedTo = 0;
  late final typing = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 260));
  final _ttsLocaleAvailable = <String, bool>{};
  static const _ttsLocales = {'영어': 'en-US', '일본어': 'ja-JP', '중국어': 'zh-CN'};
  int phraseIndex = 0;
  _PlayOrder playOrder = _PlayOrder.sequential;
  final math.Random _random = math.Random();

  /// 같은 문장을 다시 보여줄 때도 응답 UI가 새로 시작되도록 문장이 넘어갈 때마다 오른다.
  int phraseRound = 0;

  /// 지나온 문장 번호. 이전 문장 버튼이 랜덤 재생에서도 방금 본 문장으로 돌아가게 한다.
  final List<int> phraseHistory = [];

  /// 재생 방식에 맞는 다음 문장 번호. 랜덤은 방금 문장을 피한다.
  /// [skip]이면 하나 반복에서도 다음 문장으로 넘어간다.
  int nextPhraseIndex({bool skip = false}) {
    final count = phrases.length;
    phraseRound++;
    phraseHistory.add(phraseIndex);
    if (phraseHistory.length > 100) phraseHistory.removeAt(0);
    return switch (skip && playOrder == _PlayOrder.repeatOne
        ? _PlayOrder.sequential
        : playOrder) {
      _PlayOrder.sequential => (phraseIndex + 1) % count,
      _PlayOrder.repeatOne => phraseIndex % count,
      _PlayOrder.shuffle => count <= 1
          ? 0
          : (phraseIndex % count + 1 + _random.nextInt(count - 1)) % count,
    };
  }

  double totalXp = 0;
  bool xpReady = false;
  List<String> customPhrases = [];
  Set<String>? enabledRoutineIds;
  List<DefaultConversationSentence> mySentences = [];
  String get xpKey => 'parrokit.speaking.xp.v1.${widget.accountId}';
  String get countListenKey =>
      'parrokit.speaking.count_listen.v1.${widget.accountId}';
  String get gapKey => 'parrokit.speaking.gap_seconds.v1.${widget.accountId}';
  String get phrasesKey =>
      'parrokit.speaking.phrases.v1.${widget.accountId}.${widget.language}';
  int get level => totalXp ~/ 10 + 1;

  Future<void> loadXp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        totalXp = math.max(0, (prefs.get(xpKey) as num?)?.toDouble() ?? 0);
        gapSeconds = (prefs.getDouble(gapKey) ?? _defaultGapSeconds).clamp(
            _SpeakingSettingsDialog.minGap, _SpeakingSettingsDialog.maxGap);
        countListen = prefs.getBool(countListenKey) ?? true;
        xpReady = true;
      });
    } catch (_) {
      if (mounted) setState(() => xpReady = true);
    }
  }

  Future<void> showSpeakingSettings() async {
    final next = await showDialog<({double gap, bool countListen})>(
      context: context,
      builder: (context) => _SpeakingSettingsDialog(
          initialGap: gapSeconds, initialCountListen: countListen),
    );
    if (!mounted || next == null) return;
    setState(() {
      gapSeconds = next.gap;
      countListen = next.countListen;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(gapKey, next.gap);
      await prefs.setBool(countListenKey, next.countListen);
    } catch (_) {/* 저장하지 못해도 이번 실행에서는 바뀐 설정을 쓴다. */}
  }

  /// 점수(0~1)에 비례해 XP를 준다. 100점이면 1 XP. 점수 없이 직접 넘기면 최소값만 준다.
  static const _minXpGain = 0.1;

  /// XP를 소수 첫째 자리까지만 보여준다. (예: 3.5 → '3.5', 4.0 → '4')
  String xpText(double value) {
    final rounded = (value * 10).round() / 10;
    return rounded == rounded.roundToDouble()
        ? '${rounded.round()}'
        : rounded.toStringAsFixed(1);
  }

  Future<bool> awardXp(double? score) async {
    final key = xpKey;
    try {
      final prefs = await SharedPreferences.getInstance();
      final gain = math.max(_minXpGain, score ?? 0).clamp(0.0, 1.0);
      final previous = math.max(0, (prefs.get(key) as num?)?.toDouble() ?? 0);
      final next = ((previous + gain) * 100).round() / 100;
      if (!await prefs.setDouble(key, next)) {
        throw StateError('XP save failed');
      }
      if (!mounted) return false;
      setState(() {
        totalXp = next;
        xpReady = true;
      });
      final scoreText = score == null ? '' : '${(score * 100).round()}점 · ';
      final gainText = '+${xpText(gain)} XP';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(next ~/ 10 > previous ~/ 10
            ? '$scoreText$gainText · Lv.${next ~/ 10 + 1} 레벨 업!'
            : '따라 말하기 완료 · $scoreText$gainText'),
        duration: const Duration(seconds: 2),
      ));
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('XP를 저장하지 못했어요. 다시 시도해주세요.')));
      }
      return false;
    }
  }

  /// 앵무새가 말할 수 있는 전체 문장: 기본 문장 + 내가 저장·추가한 문장.
  List<DefaultConversationSentence> get allSentences => [
        ...defaultSentencesFor(widget.language),
        ...mySentences.where((s) => s.language == widget.language),
      ];

  DefaultConversationSentence? sentenceForPhrase(String text) {
    for (final sentence in allSentences) {
      if (sentence.text == text) return sentence;
    }
    return null;
  }

  List<DefaultConversationSentence> get routineDefaults {
    final defaults = allSentences;
    final enabled = enabledRoutineIds;
    return enabled == null
        ? defaults
        : defaults
            .where((sentence) => enabled.contains(sentence.id))
            .toList(growable: false);
  }

  List<String> get phrases => [
        ...routineDefaults.map((sentence) => sentence.text),
        ...customPhrases,
        if (routineDefaults.isEmpty && customPhrases.isEmpty)
          '루틴에 문장을 추가해 주세요.',
      ];
  String get phrase => phrases[phraseIndex % phrases.length];

  Future<void> loadRoutineSettings() async {
    try {
      final activities = await SentenceActivityStore.loadAll(widget.accountId);
      final mine = await MySentenceStore.load(widget.accountId);
      final enabled = [...defaultConversationSentences, ...mine]
          .where((sentence) => activities[sentence.id]?.routineEnabled ?? true)
          .map((sentence) => sentence.id)
          .toSet();
      if (!mounted) return;
      final sameMine = listEquals(
        mine.map((s) => s.id).toList(),
        mySentences.map((s) => s.id).toList(),
      );
      if (sameMine && setEquals(enabledRoutineIds, enabled)) return;
      setState(() {
        mySentences = mine;
        enabledRoutineIds = enabled;
        phraseIndex = phraseIndex % phrases.length;
      });
    } catch (_) {
      // 설정을 불러오지 못하면 기본 문장 전체를 사용한다.
    }
  }

  void handleRoutineChanged() => unawaited(loadRoutineSettings());

  /// 문장별 활동 기록. 따라 말하는 문장의 친밀도 게이지에 쓴다.
  Map<String, SentenceActivity> activities = {};

  Future<void> loadActivities() async {
    try {
      final loaded = await SentenceActivityStore.loadAll(widget.accountId);
      if (mounted) setState(() => activities = loaded);
    } catch (_) {/* 게이지만 비어 보이고 연습은 그대로 된다. */}
  }

  Future<void> loadCustomPhrases() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(phrasesKey) ?? const <String>[];
      if (!mounted) return;
      setState(() => customPhrases = saved);
    } catch (_) {/* 기본 문장만 사용한다. */}
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SentenceActivityStore.revision.addListener(handleRoutineChanged);
    SentenceActivityStore.activityRevision.addListener(loadActivities);
    unawaited(loadActivities());
    unawaited(loadSprite());
    unawaited(loadXp());
    unawaited(loadCustomPhrases());
    unawaited(loadRoutineSettings());
    unawaited(setupTts());
  }

  Future<void> setupTts() async {
    try {
      tts.setCompletionHandler(handleTtsDone);
      tts.setCancelHandler(() => ttsSpeaking = false);
      tts.setProgressHandler(handleTtsProgress);
      tts.setErrorHandler((_) {
        speakingSentenceId = null;
        handleTtsDone();
      });
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        // 음성 인식이 마이크를 쓸 수 있도록 TTS 오디오 세션이 녹음을 막지 않게 한다.
        await tts
            .setIosAudioCategory(IosTextToSpeechAudioCategory.playAndRecord, [
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ]);
      }
      await tts.setSpeechRate(0.45);
      ttsReady = true;
      if (mounted) syncPlayback();
    } catch (_) {/* 음성을 쓸 수 없으면 말풍선만 표시한다. */}
  }

  double get typedFraction =>
      typedFrom +
      (typedTo - typedFrom) * Curves.easeOut.transform(typing.value);

  void handleTtsProgress(String text, int start, int end, String word) {
    if (!mounted || !voiceTyping || text.isEmpty) return;
    typedFrom = typedFraction;
    typedTo = (end / text.length).clamp(0.0, 1.0);
    typing.forward(from: 0);
  }

  /// 음성이 끝나면, 말풍선 시간이 이미 지나 대기 중이던 다음 문장으로 넘긴다.
  void handleTtsDone() {
    ttsSpeaking = false;
    final listened = speakingSentenceId;
    speakingSentenceId = null;
    if (listened != null && countListen) {
      unawaited(SentenceActivityStore.incrementListen(
        widget.accountId,
        listened,
      ).catchError((Object _) {/* 기록 실패는 재생 흐름에 영향 주지 않는다. */}));
    }
    if (voiceTyping) {
      typedFrom = typedTo = 1;
      typing.value = 1;
    }
    if (!mounted) return;
    // 따라 말하기 모드는 앵무새 음성이 끝나면 말풍선 시간(3초)이 남아 있어도 바로 내 차례로 넘긴다.
    if (mode == _SpeakingMode.repeat && !pendingAdvance && !gapWaiting) {
      if (!animation.isAnimating || awaitingResponse || paused) return;
      animation.stop();
      advanceAfterGap();
      return;
    }
    if (!pendingAdvance) return;
    pendingAdvance = false;
    advanceAfterGap();
  }

  /// 문장이 끝나면 잠깐 쉬고 넘어간다. 자동 모드는 설정한 간격, 따라 말하기 모드는 고정 간격이다.
  void advanceAfterGap() {
    gapTimer?.cancel();
    gapWaiting = true;
    if (mounted) setState(() {});
    gapTimer = Timer(_phraseGap, () {
      gapWaiting = false;
      finishPhrase();
    });
  }

  bool get hasSpeakablePhrase =>
      routineDefaults.isNotEmpty || customPhrases.isNotEmpty;

  Future<void> speakPhrase() async {
    if (!ttsReady || !soundOn || !listenMode || !hasSpeakablePhrase) return;
    final locale = _ttsLocales[widget.language];
    if (locale == null) return;
    final text = phrase;
    try {
      final available = _ttsLocaleAvailable[locale] ??=
          (await tts.isLanguageAvailable(locale)) == true;
      if (!available || !mounted) return;
      await tts.stop();
      await tts.setLanguage(locale);
      ttsSpeaking = true;
      speakingSentenceId = sentenceForPhrase(text)?.id;
      typedFrom = typedTo = 0;
      typing.value = 0;
      voiceTyping = true;
      if (mounted) setState(() {});
      await tts.speak(text);
    } catch (_) {
      ttsSpeaking = false;
      voiceTyping = false;
    }
  }

  void stopTts() {
    speakingSentenceId = null;
    gapTimer?.cancel();
    gapWaiting = false;
    ttsSpeaking = false;
    voiceTyping = false;
    if (ttsReady) unawaited(tts.stop());
  }

  void setSound(bool on) {
    setState(() => soundOn = on);
    applyVoiceSetting();
  }

  void setListenMode(bool on) {
    setState(() => listenMode = on);
    applyVoiceSetting();
  }

  /// 소리/듣기 모드가 바뀌면 지금 말풍선에 맞춰 음성을 켜거나 끈다.
  void applyVoiceSetting() {
    if (soundOn && listenMode) {
      if (animation.isAnimating && !awaitingResponse) unawaited(speakPhrase());
      return;
    }
    final waiting = pendingAdvance || gapWaiting;
    stopTts();
    pendingAdvance = false;
    if (waiting) finishPhrase();
  }

  Future<void> loadSprite() async {
    try {
      final bytes = await rootBundle
          .load('assets/characters/nest_parrot/blink-v3-sheet.png');
      final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
      try {
        final frame = await codec.getNextFrame();
        if (!mounted) {
          frame.image.dispose();
          return;
        }
        setState(() => nestSprite = frame.image);
      } finally {
        codec.dispose();
      }
    } catch (_) {/* 파일이 없으면 앵무새 없이 배경만 그린다. */}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    visible =
        TickerMode.of(context) && (ModalRoute.of(context)?.isCurrent ?? true);
    reduceMotion = MediaQuery.disableAnimationsOf(context);
    syncPlayback();
  }

  @override
  void didUpdateWidget(covariant StagePreviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.language != widget.language) {
      phraseIndex = 0;
      phraseHistory.clear();
      awaitingResponse = false;
      customPhrases = [];
      pendingAdvance = false;
      stopTts();
      animation.reset();
      unawaited(loadCustomPhrases());
      unawaited(loadRoutineSettings());
      syncPlayback();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    syncPlayback();
  }

  void syncPlayback() {
    if (!foreground || !visible || paused) {
      animation.stop();
      birdAnimation.stop();
      // 멈춘 동안은 음성도 끊고, 재개하면 같은 문장을 처음부터 다시 말한다.
      pendingAdvance = false;
      stopTts();
      return;
    }
    if (reduceMotion) {
      birdAnimation.stop();
    } else if (!birdAnimation.isAnimating) {
      birdAnimation.repeat();
    }
    if (awaitingResponse || pendingAdvance || gapWaiting) {
      animation.stop();
    } else if (!animation.isAnimating) {
      animation.forward(from: animation.isCompleted ? 0 : animation.value);
      unawaited(speakPhrase());
    }
  }

  /// 말풍선 글자가 다 나오는 지점(전체의 약 51%). 이후는 문장이 머무르다 사라지는 구간이다.
  static const _bubbleTypedAt = 0.52;

  /// 소리 없이 글자만 보여주는 따라 말하기 모드는 글자가 다 나오면 말풍선이 사라지길
  /// 기다리지 않고 바로 내 차례로 넘긴다.
  void onBubbleTick() {
    if (mode != _SpeakingMode.repeat ||
        (soundOn && listenMode) ||
        awaitingResponse ||
        gapWaiting ||
        pendingAdvance ||
        !animation.isAnimating ||
        animation.value < _bubbleTypedAt) {
      return;
    }
    animation.stop();
    advanceAfterGap();
  }

  void onSpeechStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    // 말풍선 시간이 끝났어도 음성이 아직 나오고 있으면 끝날 때까지 기다린다.
    if (ttsSpeaking) {
      pendingAdvance = true;
      return;
    }
    advanceAfterGap();
  }

  void finishPhrase() {
    if (!mounted) return;
    gapWaiting = false;
    voiceTyping = false;
    final spokenSentence = sentenceForPhrase(phrase);
    if (spokenSentence != null) {
      unawaited(SentenceActivityStore.incrementParrotSpeak(
        widget.accountId,
        spokenSentence.id,
      ));
    }
    setState(() {
      if (mode == _SpeakingMode.repeat) {
        awaitingResponse = true;
      } else {
        phraseIndex = nextPhraseIndex();
      }
    });
    syncPlayback();
  }

  /// 앵무새가 아직 말하는 중에 내가 마이크나 체크를 누르면 앵무새를 멈추고 내 차례로 넘긴다.
  void interruptParrot() {
    if (!mounted || awaitingResponse || mode != _SpeakingMode.repeat) return;
    stopTts();
    pendingAdvance = false;
    finishPhrase();
  }

  /// 음악 플레이어처럼 다음/이전 문장으로 바로 넘어간다.
  void skipPhrase({required bool forward}) {
    if (completingResponse || !mounted) return;
    final count = phrases.length;
    stopTts();
    pendingAdvance = false;
    setState(() {
      awaitingResponse = false;
      if (forward) {
        phraseIndex = nextPhraseIndex(skip: true);
      } else {
        phraseRound++;
        phraseIndex = phraseHistory.isNotEmpty
            ? phraseHistory.removeLast() % count
            : (phraseIndex % count - 1 + count) % count;
      }
    });
    animation.reset();
    syncPlayback();
  }

  /// 목록에서 고른 문장으로 바로 이동한다.
  void jumpToPhrase(int index) {
    if (completingResponse || !mounted) return;
    stopTts();
    pendingAdvance = false;
    phraseHistory.add(phraseIndex);
    if (phraseHistory.length > 100) phraseHistory.removeAt(0);
    setState(() {
      awaitingResponse = false;
      phraseRound++;
      phraseIndex = index;
    });
    animation.reset();
    syncPlayback();
  }

  /// 지금 나오는 문장들을 목록으로 열고, 고른 문장을 바로 듣거나 따라 말한다.
  Future<void> pickPhrase() async {
    if (!hasSpeakablePhrase) return;
    final list = phrases;
    final current = phraseIndex % list.length;
    final picked = await showModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        builder: (context, controller) => Column(children: [
          Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('문장 목록', style: context.texts.titleMedium))),
          Expanded(
              child: ListView.builder(
                  key: const ValueKey('phrase-list'),
                  controller: controller,
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final sentence = sentenceForPhrase(list[i]);
                    final level = sentence == null
                        ? null
                        : affinityOf(activities[sentence.id] ??
                                const SentenceActivity())
                            .level;
                    return ListTile(
                      selected: i == current,
                      leading: i == current
                          ? const Icon(Icons.volume_up_rounded)
                          : Text('${i + 1}'),
                      title: Text(list[i]),
                      subtitle: sentence == null || sentence.translation.isEmpty
                          ? null
                          : Text(sentence.translation,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: level == null ? null : Text('Lv.$level'),
                      onTap: () => Navigator.pop(context, i),
                    );
                  })),
        ]),
      ),
    );
    if (picked != null) jumpToPhrase(picked);
  }

  void changeMode(_SpeakingMode next) {
    if (completingResponse) return;
    setState(() {
      mode = next;
      paused = false;
      awaitingResponse = false;
    });
    pendingAdvance = false;
    stopTts();
    animation.reset();
    syncPlayback();
  }

  /// 가장 최근 시도의 100점 만점 점수. 체크로 직접 완료했으면 null.
  int? lastScore;

  /// 따라 말하기 시도 하나를 학습 기록에 남긴다.
  void recordAttempt(PracticeAttemptResult result) {
    lastScore = result.score == null ? null : (result.score! * 100).round();
    final sentence = sentenceForPhrase(phrase);
    if (sentence == null) return;
    unawaited(PracticeLogStore.add(
      widget.accountId,
      PracticeAttempt(
        at: DateTime.now(),
        sentenceId: sentence.id,
        score: result.score,
        heard: result.heard,
        success: result.success,
        manual: result.manual,
        durationMs: result.duration.inMilliseconds,
      ),
    ).catchError((Object _) {/* 기록 실패는 연습 흐름에 영향 주지 않는다. */}));
  }

  Future<void> completeRepeat(double? score) async {
    if (!awaitingResponse || completingResponse) return;
    setState(() => completingResponse = true);
    try {
      final saved = await awardXp(score);
      if (!saved) return;
      final practicedSentence = sentenceForPhrase(phrase);
      if (practicedSentence != null) {
        await SentenceActivityStore.incrementPractice(
          widget.accountId,
          practicedSentence.id,
        );
      }
      await widget.onPracticeCompleted?.call();
      if (!mounted) return;
      setState(() {
        awaitingResponse = false;
        phraseIndex = nextPhraseIndex();
      });
      animation.reset();
    } finally {
      if (mounted) {
        setState(() => completingResponse = false);
        syncPlayback();
      }
    }
  }

  /// 말풍선을 누르면 보관함과 같은 문장 정보 시트를 연다.
  Future<void> openPhraseDetails() async {
    final sentence = sentenceForPhrase(phrase);
    if (sentence == null) return;
    await showSentenceDetails(
      context,
      sentence: sentence,
      accountId: widget.accountId,
    );
  }

  Future<void> addPhrase() async {
    ({AddedSentence sentence, bool added})? result;
    try {
      result = await addSentenceFlow(
        context,
        accountId: widget.accountId,
        language: widget.language,
      );
      if (result != null) await loadRoutineSettings();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('문장을 저장하지 못했어요. 다시 시도해주세요.')));
      }
      return;
    }
    if (!mounted || result == null) return;
    // 다른 언어로 추가했으면 지금 보는 문장은 그대로 둔다.
    if (result.sentence.language != widget.language) return;
    final index = phrases.indexOf(result.sentence.text);
    setState(() {
      if (index >= 0) phraseIndex = index;
      awaitingResponse = false;
    });
    pendingAdvance = false;
    stopTts();
    animation.reset();
    syncPlayback();
  }

  Future<void> showPhraseSettings() async {
    final action = await showDialog<String>(
        context: context,
        builder: (context) => _PhraseSettingsDialog(
          accountId: widget.accountId,
          initialLanguage: widget.language,
          mySentences: mySentences,
          initialEnabled: {
            for (final sentence in [
              for (final language in availableLearningLanguages)
                ...defaultSentencesFor(language.label),
              ...mySentences,
            ])
              sentence.id:
                  activities[sentence.id]?.routineEnabled ?? true,
          },
        ),
      );
    // 창의 + 버튼은 창을 닫고 왼쪽 '문장 추가'와 같은 흐름을 연다.
    if (action == _PhraseSettingsDialog.addAction && mounted) {
      await addPhrase();
    }
  }

  Future<void> showHelp() => showDialog<void>(
      context: context, builder: (context) => const _HomeHelpDialog());

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SentenceActivityStore.revision.removeListener(handleRoutineChanged);
    SentenceActivityStore.activityRevision.removeListener(loadActivities);
    stopTts();
    typing.dispose();
    animation.dispose();
    birdAnimation.dispose();
    nestSprite?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = HomeTokens.of(context);
    final muted = palette.muted;
    final accent = palette.primary;
    final content =
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
          height:
              (widget.embedded ? MediaQuery.paddingOf(context).top : 0) + 16),
      Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(
                      widget.nickname.trim().isEmpty ? '나' : widget.nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.titleLarge
                          .copyWith(color: palette.ink))),
              Text('Lv.$level',
                  style: context.texts.titleMedium
                      .copyWith(color: palette.primary)),
              const SizedBox(width: 6),
              Semantics(
                  label: '도움말',
                  button: true,
                  child: Tooltip(
                      message: '도움말',
                      excludeFromSemantics: true,
                      child: InkResponse(
                          key: const ValueKey('home-help'),
                          radius: 18,
                          onTap: showHelp,
                          child: Icon(Icons.help_outline_rounded,
                              size: 22, color: palette.muted)))),
            ]),
            const SizedBox(height: 10),
            ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                    value: (totalXp % 10) / 10,
                    minHeight: 5,
                    color: palette.primary,
                    backgroundColor: palette.surfaceAlt)),
            const SizedBox(height: 6),
            Align(
                alignment: Alignment.centerRight,
                child: Text(
                    xpReady ? '${xpText(totalXp % 10)} / 10 XP' : 'XP 불러오는 중…',
                    style: context.texts.labelSmall.copyWith(color: muted))),
          ])),
      Container(
          // 아래 아이콘 줄을 무대 밖 글자 달린 줄로 옮겨서 무대가 낮다(4차).
          height: 270,
          width: double.infinity,
          color: palette.background,
          child: Stack(children: [
            Positioned.fill(
                bottom: 4,
                child: Semantics(
                    label: '앵무새가 이야기해요. $phrase',
                    child: LayoutBuilder(
                        builder: (context, constraints) => AnimatedBuilder(
                            animation: Listenable.merge(
                                [animation, birdAnimation, typing]),
                            builder: (context, _) {
                              final moving = !reduceMotion && !paused;
                              // 음성이 이어지는 동안은 말풍선 시간이 끝나도 사라지지 않게 붙잡는다.
                              final holdBubble =
                                  voiceTyping && (ttsSpeaking || gapWaiting);
                              final phase = awaitingResponse
                                  ? 0.6
                                  : holdBubble
                                      ? math.min(animation.value, 0.6)
                                      : animation.value;
                              return GestureDetector(
                                  key: const ValueKey('phrase-bubble'),
                                  behavior: HitTestBehavior.translucent,
                                  onTapUp: (details) {
                                    if (_GrowthPainter.bubbleRect(
                                            Size(constraints.maxWidth,
                                                constraints.maxHeight),
                                            phrase)
                                        .inflate(6)
                                        .contains(details.localPosition)) {
                                      openPhraseDetails();
                                    }
                                  },
                                  child: CustomPaint(
                                      painter: _GrowthPainter(
                                          typedFraction: voiceTyping
                                              ? typedFraction
                                              : null,
                                          phase: phase,
                                          birdPhase: birdAnimation.value,
                                          sprite: nestSprite,
                                          phrase: phrase,
                                          animate: moving,
                                          groundOuter: HomeTokens.of(context)
                                              .groundOuter,
                                          groundInner: HomeTokens.of(context)
                                              .groundInner)));
                            })))),
            Positioned(
                left: 8,
                top: 30,
                child: Column(children: [
                  _GameMenuButton(
                      label: soundOn ? '소리 끄기' : '소리 켜기',
                      icon: soundOn
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      selected: soundOn,
                      onTap: () => setSound(!soundOn)),
                  const SizedBox(height: 7),
                  _GameMenuButton(
                      key: const ValueKey('add-phrase'),
                      label: '문장 추가',
                      icon: Icons.add_comment_rounded,
                      onTap: addPhrase),
                  const SizedBox(height: 7),
                  _GameMenuButton(
                      label: '문장 설정',
                      icon: Icons.tune_rounded,
                      badge: true,
                      onTap: showPhraseSettings),
                  const SizedBox(height: 7),
                  _GameMenuButton(
                      label: '말하기 설정',
                      icon: Icons.settings_rounded,
                      onTap: showSpeakingSettings),
                ])),
            // 눌러도 아무 일 없던 준비 중 버튼(캐릭터 정보, 꾸미기, 보관함, 도전
            // 과제, 쇼츠 학습, 공유 영상, 학습 기록)과 글자 없는 아이콘 줄은
            // 4차에서 아래 글자 달린 조작 줄로 바꾸며 지웠다.
          ])),
      Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
          child: Row(children: [
            _LabeledControl(
                key: const ValueKey('mode-repeat'),
                label: '따라 말하기',
                tooltip: mode == _SpeakingMode.repeat
                    ? '따라 말하기 모드 끄기'
                    : '따라 말하기 모드 켜기',
                icon: Icons.record_voice_over_rounded,
                selected: mode == _SpeakingMode.repeat,
                onTap: () => changeMode(mode == _SpeakingMode.repeat
                    ? _SpeakingMode.automatic
                    : _SpeakingMode.repeat)),
            _LabeledControl(
                label: '듣기',
                tooltip: listenMode ? '듣기 모드 끄기' : '듣기 모드 켜기',
                icon: Icons.headphones_rounded,
                selected: listenMode,
                onTap: () => setListenMode(!listenMode)),
            _LabeledControl(
                key: const ValueKey('previous-phrase'),
                label: '이전',
                tooltip: '이전 문장',
                icon: Icons.skip_previous_rounded,
                onTap: () => skipPhrase(forward: false)),
            _LabeledControl(
                label: paused ? '재생' : '멈춤',
                tooltip: paused ? '말하기 재개' : '말하기 일시 정지',
                icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                emphasized: true,
                onTap: () {
                  setState(() => paused = !paused);
                  syncPlayback();
                }),
            _LabeledControl(
                key: const ValueKey('next-phrase'),
                label: '다음',
                tooltip: '다음 문장',
                icon: Icons.skip_next_rounded,
                onTap: () => skipPhrase(forward: true)),
            _LabeledControl(
                key: const ValueKey('play-order'),
                label: playOrder.label,
                tooltip: '재생 순서: ${playOrder.label}',
                icon: playOrder.icon,
                selected: playOrder != _PlayOrder.sequential,
                onTap: () => setState(() => playOrder = playOrder.next)),
            _LabeledControl(
                key: const ValueKey('phrase-list-button'),
                label: '목록',
                tooltip: '문장 목록',
                icon: Icons.queue_music_rounded,
                onTap: pickPhrase),
          ]),
        ),
      if (awaitingResponse || mode == _SpeakingMode.repeat)
        Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Column(children: [
              if (sentenceForPhrase(phrase) case final sentence?) ...[
                SentenceAffinityBar(
                    key: const ValueKey('repeat-affinity'),
                    affinity: affinityOf(
                        activities[sentence.id] ?? const SentenceActivity()),
                    compact: true),
                const SizedBox(height: 14),
              ],
              _SpeechWavePreview(
                  key: ValueKey('${widget.language}-$phraseIndex-$phraseRound'),
                  phrase: phrase,
                  localeId: _speechLocales[widget.language] ?? 'en_US',
                  recognizer: recognizer,
                  enabled: !completingResponse && !paused,
                  reduceMotion: reduceMotion,
                  onAttempt: recordAttempt,
                  onBeforeStart: interruptParrot,
                  onComplete: completeRepeat),
            ])),
      const SizedBox(height: 16),
      const SizedBox(height: 16),
    ]);
    // 앱 테마에서 파생시킨다 (character_dashboard_screen과 같은 이유).
    final appTheme = Theme.of(context);
    final theme = appTheme.copyWith(
        colorScheme: appTheme.colorScheme.copyWith(
      primary: accent,
      surface: palette.surface,
      onSurface: palette.ink,
    ));
    return Theme(
        data: theme,
        child: widget.embedded
            ? Container(color: palette.background, child: content)
            : Scaffold(
                backgroundColor: palette.background,
                appBar: AppBar(title: const Text('앵무새와 말하기')),
                body: SingleChildScrollView(
                    padding: EdgeInsets.only(
                        bottom: MediaQuery.paddingOf(context).bottom + 120),
                    child: content)));
  }
}

/// 위젯이 시도 하나가 끝났을 때 넘겨주는 결과.
class PracticeAttemptResult {
  const PracticeAttemptResult({
    required this.score,
    required this.heard,
    required this.success,
    required this.manual,
    required this.duration,
  });

  final double? score;
  final String heard;
  final bool success;
  final bool manual;
  final Duration duration;
}

/// 마이크를 눌러 말하면 인식된 만큼 문장 색이 채워지고, 충분히 비슷하면 완료한다.
class _SpeechWavePreview extends StatefulWidget {
  const _SpeechWavePreview(
      {super.key,
      required this.phrase,
      required this.localeId,
      required this.recognizer,
      required this.enabled,
      required this.reduceMotion,
      required this.onAttempt,
      required this.onBeforeStart,
      required this.onComplete});
  final String phrase;
  final String localeId;
  final PhraseRecognizer recognizer;
  final bool enabled;
  final bool reduceMotion;
  final void Function(double? score) onComplete;

  /// 마이크를 켜거나 체크를 누르기 직전에 부른다. 앵무새가 말하는 중이면 멈추게 한다.
  final VoidCallback onBeforeStart;

  /// 시도가 끝날 때마다 알린다. 점수는 인식 없이 직접 넘긴 경우 null.
  final void Function(PracticeAttemptResult result) onAttempt;
  @override
  State<_SpeechWavePreview> createState() => _SpeechWavePreviewState();
}

class _SpeechWavePreviewState extends State<_SpeechWavePreview> {
  bool listening = false;
  double score = 0;

  /// 지금 마이크로 들어오는 목소리 크기(0~1).
  double level = 0;

  /// 이 크기를 넘어야 소리가 난다고 보고 음파를 켠다.
  static const _voiceThreshold = 0.25;
  String? message;

  /// 마이크를 켠 시각과 그동안 인식된 말. 시도가 끝나면 기록으로 넘긴다.
  DateTime? attemptStart;
  String heard = '';

  @override
  void didUpdateWidget(covariant _SpeechWavePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && listening) unawaited(stopListening());
  }

  Future<void> toggleListening() async {
    if (!widget.enabled) return;
    if (listening) return stopListening();
    widget.onBeforeStart();
    setState(() {
      score = 0;
      message = null;
    });
    heard = '';
    var started = false;
    try {
      started = await widget.recognizer.start(
        localeId: widget.localeId,
        onResult: handleResult,
        onDone: handleDone,
        onLevel: handleLevel,
      );
    } catch (_) {/* 플러그인이 없거나 권한이 막힌 경우로 본다. */}
    if (!mounted) return;
    if (!started) {
      setState(
          () => message = '음성 인식을 쓸 수 없어요. 마이크와 음성 인식 권한을 확인하거나 체크로 넘어가세요.');
      return;
    }
    attemptStart = DateTime.now();
    setState(() => listening = true);
  }

  /// 진행 중인 시도를 기록으로 넘긴다. 이미 넘겼으면 아무것도 하지 않는다.
  void finishAttempt({required bool success, bool manual = false}) {
    final start = attemptStart;
    if (start == null && !manual) return;
    attemptStart = null;
    widget.onAttempt(PracticeAttemptResult(
      score: manual && score == 0 ? null : score,
      heard: heard,
      success: success,
      manual: manual,
      duration:
          start == null ? Duration.zero : DateTime.now().difference(start),
    ));
  }

  void handleResult(String text) {
    if (!mounted || !listening) return;
    heard = text;
    final next = speechMatchScore(widget.phrase, text);
    setState(() => score = math.max(score, next));
    if (score >= speechPassScore) {
      // 통과선을 넘어도 끝까지 말할 수 있게 계속 듣는다. 다 맞췄거나 잠깐 말이 없으면 끝낸다.
      passTimer?.cancel();
      if (score >= 0.999) {
        completePass();
      } else {
        passTimer = Timer(_passQuietGap, completePass);
      }
    }
  }

  /// 통과 후 이만큼 새 인식이 없으면 말이 끝난 것으로 보고 점수를 확정한다.
  static const _passQuietGap = Duration(milliseconds: 1500);
  Timer? passTimer;

  void completePass() {
    passTimer?.cancel();
    if (!mounted || !listening) return;
    finishAttempt(success: true);
    unawaited(stopListening());
    setState(() => message = '잘했어요! 체크를 누르면 다음 문장으로 넘어가요.');
  }

  /// 실제 입력 크기를 받아 막대에 반영한다. 급하게 튀지 않게 조금씩 따라가게 한다.
  void handleLevel(double next) {
    if (!mounted || !listening) return;
    setState(() => level = level + (next - level) * 0.5);
  }

  void handleDone(String? error) {
    if (!mounted || !listening) return;
    passTimer?.cancel();
    finishAttempt(success: score >= speechPassScore);
    setState(() {
      listening = false;
      level = 0;
      message = score < speechPassScore
          ? '다시 한번 말해볼까요?'
          : '잘했어요! 체크를 누르면 다음 문장으로 넘어가요.';
    });
  }

  Future<void> stopListening() async {
    passTimer?.cancel();
    finishAttempt(success: score >= speechPassScore);
    if (mounted) {
      setState(() {
        listening = false;
        level = 0;
      });
    }
    try {
      await widget.recognizer.stop();
    } catch (_) {/* 이미 멈춘 인식은 무시한다. */}
  }

  @override
  void dispose() {
    passTimer?.cancel();
    unawaited(widget.recognizer.stop().catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = HomeTokens.of(context);
    final active = palette.primary;
    final idle = palette.muted;
    final letters = widget.phrase.characters.toList();
    final highlighted = (score * letters.length).floor();
    return Column(children: [
      Text.rich(
          TextSpan(children: [
            TextSpan(
                text: letters.take(highlighted).join(),
                style: TextStyle(color: active)),
            TextSpan(
                text: letters.skip(highlighted).join(),
                style: TextStyle(color: idle)),
          ]),
          textAlign: TextAlign.center,
          style: context.texts.headlineSmall.copyWith(height: 1.5)),
      if (score > 0) ...[
        const SizedBox(height: 8),
        Text('${(score * 100).round()}점',
            key: const ValueKey('speech-score'),
            style: context.texts.titleLarge
                .copyWith(color: score >= speechPassScore ? active : idle)),
      ],
      const SizedBox(height: 16),
      Row(children: [
        Semantics(
            label: listening ? '음성 인식 중지' : '마이크를 누르고 따라 말하기',
            button: true,
            child: IconButton.filledTonal(
                key: const ValueKey('preview-microphone'),
                tooltip: listening ? '음성 인식 중지' : '따라 말하기 시작',
                onPressed: widget.enabled ? toggleListening : null,
                style: IconButton.styleFrom(
                    backgroundColor: listening
                        ? active
                        : palette.primary.withValues(alpha: 0.12),
                    foregroundColor: listening ? palette.surface : active),
                icon:
                    Icon(listening ? Icons.stop_rounded : Icons.mic_rounded))),
        const SizedBox(width: 12),
        Expanded(
            child: SizedBox(
                height: 48,
                child: LayoutBuilder(builder: (context, constraints) {
                  final count = math.max(1, (constraints.maxWidth / 7).floor());
                  return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(count, (i) {
                        final base = 8 + (math.sin(i * 1.7).abs() * 23);
                        // 소리가 날 때만 막대가 색을 띠고 크기에 맞춰 커진다. 조용하면 낮게 멈춘다.
                        final voiced = listening && level > _voiceThreshold;
                        final strength = voiced
                            ? (level - _voiceThreshold) / (1 - _voiceThreshold)
                            : 0.0;
                        final wave = 0.2 + strength * 0.8;
                        return Container(
                            key: ValueKey('wave-bar-$i'),
                            width: 3,
                            height: base * wave,
                            decoration: BoxDecoration(
                                color: voiced ? active : palette.surfaceAlt,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.track)));
                      }));
                }))),
        const SizedBox(width: 12),
        IconButton(
            key: const ValueKey('complete-repeat'),
            tooltip: '따라 말하기 완료',
            onPressed: widget.enabled
                ? () {
                    widget.onBeforeStart();
                    // 이미 기록된 시도(말하고 끝난 경우)는 다시 기록하지 않는다.
                    if (attemptStart != null || score == 0) {
                      finishAttempt(success: true, manual: true);
                    }
                    unawaited(stopListening());
                    widget.onComplete(score > 0 ? score : null);
                  }
                : null,
            icon: Icon(Icons.check_circle_rounded, color: active, size: 30)),
      ]),
      if (message != null)
        Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(message!,
                textAlign: TextAlign.center,
                style: context.texts.bodySmall.copyWith(color: idle))),
    ]);
  }
}

/// 앵무새가 한 문장을 말하고 다음 문장으로 넘어가기 전 쉬는 시간을 정한다.
class _SpeakingSettingsDialog extends StatefulWidget {
  const _SpeakingSettingsDialog(
      {required this.initialGap, required this.initialCountListen});
  final double initialGap;
  final bool initialCountListen;

  static const minGap = 0.5;
  static const maxGap = 10.0;

  @override
  State<_SpeakingSettingsDialog> createState() =>
      _SpeakingSettingsDialogState();
}

class _SpeakingSettingsDialogState extends State<_SpeakingSettingsDialog> {
  late double gap = widget.initialGap;
  late bool countListen = widget.initialCountListen;

  @override
  Widget build(BuildContext context) {
    final palette = HomeTokens.of(context);
    return AlertDialog(
      title: const Text('설정'),
      content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Expanded(
                  child: Text('앵무새 말하기 간격',
                      style: TextStyle(fontWeight: FontWeight.w700))),
              Text('${gap.toStringAsFixed(1)}초',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
            Slider(
                key: const ValueKey('gap-slider'),
                value: gap,
                min: _SpeakingSettingsDialog.minGap,
                max: _SpeakingSettingsDialog.maxGap,
                divisions: 19,
                label: '${gap.toStringAsFixed(1)}초',
                onChanged: (value) => setState(() => gap = value)),
            Text(
                '앵무새가 문장을 다 말한 뒤 다음 문장으로 넘어가기 전에 쉬는 시간이에요. 따라 말하기 모드에서는 적용되지 않아요.',
                style: context.texts.bodySmall.copyWith(color: palette.muted)),
            const SizedBox(height: 8),
            SwitchListTile(
                key: const ValueKey('count-listen-switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('들은 횟수 기록',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('끄면 앵무새 말을 끝까지 들어도 들은 횟수가 오르지 않아요.',
                    style: context.texts.bodySmall),
                value: countListen,
                onChanged: (value) => setState(() => countListen = value)),
          ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(
            onPressed: () =>
                Navigator.pop(context, (gap: gap, countListen: countListen)),
            child: const Text('저장')),
      ],
    );
  }
}

class _PhraseSettingsDialog extends StatefulWidget {
  const _PhraseSettingsDialog({
    required this.accountId,
    required this.initialLanguage,
    required this.mySentences,
    required this.initialEnabled,
  });

  final String accountId;
  final String initialLanguage;
  final List<DefaultConversationSentence> mySentences;

  /// 문장 id → 앵무새가 말하는지. 문장 탭의 '앵무새 끄기'와 같은 값이다.
  final Map<String, bool> initialEnabled;

  /// + 버튼으로 닫을 때 돌려주는 값.
  static const addAction = 'add';

  @override
  State<_PhraseSettingsDialog> createState() => _PhraseSettingsDialogState();
}

class _PhraseSettingsDialogState extends State<_PhraseSettingsDialog> {
  late String language;
  late final Map<String, bool> enabled = {...widget.initialEnabled};

  @override
  void initState() {
    super.initState();
    language = widget.initialLanguage;
  }

  List<DefaultConversationSentence> get visibleSentences => [
        ...defaultSentencesFor(language),
        ...widget.mySentences.where((s) => s.language == language),
      ];

  bool isOn(DefaultConversationSentence sentence) =>
      enabled[sentence.id] ?? true;

  /// 체크를 바꾸면 바로 저장한다. 예전에는 '적용'을 눌러도 저장되지 않고
  /// 창을 닫으면 사라졌다. 저장 이벤트(SentenceActivityStore.revision)로 무대와
  /// 문장 탭이 곧바로 다시 읽는다. 지금 언어에서 마지막 하나는 끌 수 없다.
  void toggle(DefaultConversationSentence sentence, bool value) {
    if (!value && visibleSentences.where(isOn).length <= 1) return;
    setState(() => enabled[sentence.id] = value);
    unawaited(SentenceActivityStore.setRoutineEnabled(
        widget.accountId, sentence.id, value));
  }

  @override
  Widget build(BuildContext context) {
    final palette = HomeTokens.of(context);
    final ink = palette.ink;
    final muted = palette.muted;
    final active = palette.primary;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xxl)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 570),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(children: [
            Row(children: [
              Expanded(
                  // 여는 버튼 이름과 맞춘다. 예전 제목 '말하기 설정'은 옆 버튼
                  // (말하기 간격 설정) 이름과 같아 헷갈렸다.
                  child: Text('문장 설정',
                      style: context.texts.headlineSmall.copyWith(color: ink))),
              IconButton(
                  tooltip: '닫기',
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: muted)),
            ]),
            const SizedBox(height: 8),
            LearningLanguagePicker(
              value: language,
              onChanged: (value) => setState(() => language = value),
            ),
            const SizedBox(height: 8),
            Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                    color: palette.surfaceSoft,
                    borderRadius: BorderRadius.circular(AppRadius.md)),
                child: Row(children: [
                  Icon(Icons.lock_outline_rounded, size: 16, color: muted),
                  const SizedBox(width: 7),
                  Text('그 외 언어는 준비 중',
                      style: context.texts.bodySmall.copyWith(color: muted)),
                ])),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                  child: Text('앵무새가 말할 문장',
                      style: context.texts.bodyLarge.copyWith(color: ink))),
              Text(
                  '${visibleSentences.where(isOn).length} / ${visibleSentences.length}',
                  style: context.texts.bodySmall.copyWith(color: muted)),
            ]),
            const SizedBox(height: 8),
            Expanded(
                child: ListView.separated(
                    itemCount: visibleSentences.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final sentence = visibleSentences[index];
                      final selected = isOn(sentence);
                      return Material(
                          color: selected
                              ? palette.primary.withValues(alpha: 0.12)
                              : palette.surfaceSoft,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: CheckboxListTile(
                              dense: true,
                              value: selected,
                              activeColor: active,
                              checkColor: Colors.white,
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              title: Text(sentence.text,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.texts.bodyMedium
                                      .copyWith(color: ink)),
                              onChanged: (value) =>
                                  toggle(sentence, value ?? false)));
                    })),
            const SizedBox(height: 14),
            // '적용' 버튼은 없앴다. 체크가 바로 저장되고 닫기는 위 X로 한다.
            // 문장 추가는 창을 닫고 무대의 '문장 추가' 흐름을 연다.
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                  key: const ValueKey('phrase-settings-add'),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48)),
                  onPressed: () => Navigator.pop(
                      context, _PhraseSettingsDialog.addAction),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('문장 추가')),
            ),
          ]),
        ),
      ),
    );
  }
}

class _HomeHelpDialog extends StatelessWidget {
  const _HomeHelpDialog();

  // 4차에서 무대 버튼을 정리한 뒤의 모양에 맞춘다. 예전에는 지운 준비 중
  // 버튼(캐릭터 정보, 꾸미기, 쇼츠 학습 등)까지 설명하고 있었다.
  static const _sections = <(String, List<(IconData, String, String)>)>[
    (
      '왼쪽 버튼',
      [
        (
          Icons.volume_up_rounded,
          '소리',
          '앵무새 목소리를 켜고 끕니다. 듣기와 함께 켜져 있어야 문장을 읽어줘요.'
        ),
        (Icons.add_comment_rounded, '문장 추가', '내가 연습할 문장을 직접 추가합니다.'),
        (
          Icons.tune_rounded,
          '문장 설정',
          '앵무새가 말할 문장을 고릅니다. 체크하면 바로 반영돼요.'
        ),
        (Icons.settings_rounded, '말하기 설정', '말하기 간격과 들은 횟수 기록 여부를 정합니다.'),
      ]
    ),
    (
      '아래 줄',
      [
        (
          Icons.record_voice_over_rounded,
          '따라 말하기',
          '앵무새가 말한 문장을 마이크로 따라 말하고 점수를 받습니다.'
        ),
        (Icons.headphones_rounded, '듣기', '켜면 앵무새가 문장을 소리 내어 읽어줍니다.'),
        (Icons.skip_next_rounded, '이전 · 다음', '앞뒤 문장으로 넘어갑니다.'),
        (Icons.pause_rounded, '멈춤 · 재생', '앵무새 말하기를 잠시 멈추거나 다시 시작합니다.'),
        (Icons.repeat_rounded, '재생 순서', '순서대로, 하나 반복, 랜덤 순서로 바꿉니다.'),
        (Icons.queue_music_rounded, '목록', '문장 목록에서 바로 고릅니다.'),
      ]
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = HomeTokens.of(context);
    return AlertDialog(
      title: const Text('도움말'),
      content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                for (final (title, items) in _sections) ...[
                  Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 6),
                      child: Text(title,
                          style: context.texts.labelMedium
                              .copyWith(color: palette.primary))),
                  for (final (icon, name, desc) in items)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(icon, size: 22, color: palette.muted),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    Text(desc,
                                        style: context.texts.bodySmall
                                            .copyWith(color: palette.muted)),
                                  ])),
                            ])),
                ],
              ]))),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('닫기')),
      ],
    );
  }
}

class _GameMenuButton extends StatelessWidget {
  const _GameMenuButton(
      {super.key,
      required this.label,
      required this.icon,
      this.selected = false,
      this.badge = false,
      required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final bool badge;
  // 아래 아이콘 줄(40pt)이 사라져 크기는 44pt 하나만 남았다.
  static const double dimension = 44;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final palette = HomeTokens.of(context);
    return SizedBox.square(
      dimension: dimension,
      child: Semantics(
        label: label,
        selected: selected,
        button: true,
        child: Tooltip(
          message: label,
          excludeFromSemantics: true,
          child: Material(
            color: selected ? palette.primary : palette.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                side: BorderSide(
                    color: selected ? palette.primary : palette.border)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
                onTap: onTap,
                child: Stack(alignment: Alignment.center, children: [
                  Icon(icon,
                      size: 23,
                      color: selected ? Colors.white : palette.muted),
                  if (badge)
                    Positioned(
                        top: 5,
                        right: 5,
                        child: Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                                color: Color(0xFFFF8E72),
                                shape: BoxShape.circle))),
                  if (selected)
                    Positioned(
                        bottom: 5,
                        child: Container(
                            width: 12,
                            height: 2,
                            decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.75),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.track)))),
                ])),
          ),
        ),
      ),
    );
  }
}

class _GrowthPainter extends CustomPainter {
  _GrowthPainter(
      {this.birdPhase = 0,
      this.sprite,
      required this.phase,
      required this.phrase,
      required this.animate,
      required this.groundOuter,
      required this.groundInner,
      this.typedFraction});
  final double birdPhase;
  final ui.Image? sprite;
  final double phase;
  final String phrase;
  final bool animate;

  /// 둥지 바닥 그림자 색. CustomPainter에는 context가 없어 받아서 쓴다.
  final Color groundOuter;
  final Color groundInner;

  /// null이면 애니메이션 시간으로, 값이 있으면 음성 진행 비율로 글자를 보여준다.
  final double? typedFraction;

  // CustomPainter에는 BuildContext가 없어서 스케일 상수를 직접 쓴다.
  static final _speechStyle =
      AppTextScale.labelMedium.copyWith(color: const Color(0xFF253C34));

  static TextPainter _speechPainter(Size size, String phrase) => TextPainter(
      text: TextSpan(text: phrase, style: _speechStyle),
      textDirection: TextDirection.ltr)
    ..layout(maxWidth: size.width * 0.58);

  /// 말풍선이 그려지는 영역. 터치 판정에도 같이 쓴다.
  static Rect bubbleRect(Size size, String phrase) {
    final fullSpeech = _speechPainter(size, phrase);
    final bubbleWidth = fullSpeech.width + 24;
    final left = ((size.width - bubbleWidth) / 2)
        .clamp(4.0, math.max(4.0, size.width - bubbleWidth - 4));
    return Rect.fromLTWH(
        left.toDouble(), 16, bubbleWidth, fullSpeech.height + 16);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    canvas.save();
    canvas.translate(0, 30);
    NestScenePainter(
            phase: birdPhase,
            joy: 0,
            meals: 0,
            sprite: sprite,
            groundOuter: groundOuter,
            groundInner: groundInner)
        .paint(canvas, Size(size.width, size.height - 30));
    canvas.restore();
    // 등장 → 한 글자씩 표시 → 잠깐 유지 → 사라짐. 위치와 크기는 고정한다.
    if (phrase.isNotEmpty && (!animate || (phase >= 0.08 && phase < 0.88))) {
      final speechStyle = _speechStyle;
      final fullSpeech = _speechPainter(size, phrase);
      final letters = phrase.characters.toList();
      final typed = typedFraction != null
          ? (typedFraction!.clamp(0.0, 1.0) * letters.length).ceil()
          : animate
              ? (((phase - 0.08) / 0.43).clamp(0.0, 1.0) * letters.length)
                  .ceil()
              : letters.length;
      final speech = TextPainter(
          text: TextSpan(text: letters.take(typed).join(), style: speechStyle),
          textDirection: TextDirection.ltr)
        ..layout(minWidth: fullSpeech.width, maxWidth: fullSpeech.width);
      final bubble = bubbleRect(size, phrase);
      final opacity = !animate
          ? 1.0
          : math.min(((phase - 0.08) / 0.05).clamp(0.0, 1.0),
              ((0.88 - phase) / 0.06).clamp(0.0, 1.0));
      canvas.saveLayer(bubble.inflate(10),
          Paint()..color = Colors.white.withValues(alpha: opacity));
      paint.color = const Color(0xFFFFFBE3);
      canvas.drawRRect(
          RRect.fromRectAndRadius(bubble, const Radius.circular(AppRadius.md)),
          paint);
      final tail = Path()
        ..moveTo(bubble.center.dx - 5, bubble.bottom - 1)
        ..lineTo(bubble.center.dx + 1, bubble.bottom + 6)
        ..lineTo(bubble.center.dx + 7, bubble.bottom - 1)
        ..close();
      canvas.drawPath(tail, paint);
      speech.paint(canvas, Offset(bubble.left + 12, bubble.top + 8));
      canvas.restore();
      fullSpeech.dispose();
      speech.dispose();
    }
  }

  @override
  bool shouldRepaint(covariant _GrowthPainter oldDelegate) => true;
}

/// 새 디자인 무대 아래 줄의 버튼. 아이콘 아래에 글자를 붙인다. 전에는 글자
/// 없는 아이콘 9개가 가로로 흘러서 무엇을 하는지 눌러 봐야 알았다.
class _LabeledControl extends StatelessWidget {
  const _LabeledControl({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
    this.emphasized = false,
    this.tooltip,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;

  /// 길게 누르면 보이는 설명. 없으면 [label]. 글자가 짧은 조작(이전·목록)도
  /// 무엇을 하는지 끝까지 말해 준다.
  final String? tooltip;

  /// 재생·멈춤처럼 가장 자주 누르는 버튼. 채운 원으로 그린다.
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final palette = HomeTokens.of(context);
    final active = selected || emphasized;
    final iconColor = emphasized
        ? palette.onAccent
        : selected
            ? palette.primary
            : palette.inkSoft;
    return Expanded(
      child: Tooltip(
        message: tooltip ?? label,
        child: Semantics(
        button: true,
        selected: selected,
        label: tooltip ?? label,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onTap,
          radius: 32,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: emphasized
                      ? palette.primary
                      : selected
                          ? palette.primary.withValues(alpha: 0.12)
                          : palette.surface,
                  border: active ? null : Border.all(color: palette.border),
                ),
                child: Icon(icon, size: 22, color: iconColor),
              ),
              const SizedBox(height: 4),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.labelSmall.copyWith(
                      color: selected ? palette.primary : palette.muted,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500)),
            ]),
          ),
        ),
      ),
      ),
    );
  }
}
