import 'package:parrokit/core/shared/utils/action_failed_text.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:parrokit/core/shared/utils/audio_focus.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';
import 'package:parrokit/core/shared/widgets/speak_controls.dart'
    show ttsNoVoiceHint;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parrokit/core/content/add_sentence_controller.dart';
import 'package:parrokit/core/content/default_conversation_sentences.dart';
import 'package:parrokit/core/content/my_sentence_store.dart';
import 'package:parrokit/core/content/practice_log.dart';
import 'package:parrokit/core/content/sentence_activity_store.dart';
import 'package:parrokit/core/content/sentence_mastery.dart';
import 'package:parrokit/core/shared/widgets/learning_language_picker.dart';
import 'package:parrokit/core/shared/widgets/sentence_affinity_bar.dart';
import 'package:parrokit/core/speech/phrase_recognizer.dart';
import 'package:parrokit/core/speech/presentation/speech_practice_view.dart';
import 'package:parrokit/features/collection/shell/presentation/widgets/sentence_collection_preview.dart'
    show showSentenceDetails;
import 'add_sentence_screen.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'nest_preview.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/widgets/app_bottom_sheet.dart';
import 'package:parrokit/core/content/speaking_xp.dart';
import 'package:parrokit/core/content/parrot_xp_day.dart';

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

  /// 창(문장 목록·설정·추가)이 떠 있는 동안은 앵무새를 쉬게 한다. 전에는
  /// 목록을 열어 둔 채 문장이 넘어가서, 목록의 '지금 문장' 표시가 실제와
  /// 어긋나고 가린 화면 뒤에서 계속 소리가 났다(5차).
  bool sheetOpen = false;
  bool foreground = true;
  bool visible = true;
  bool reduceMotion = false;
  bool awaitingResponse = false;
  bool completingResponse = false;
  bool soundOn = true;

  /// '문장 설정' 버튼의 주황 점. 예전엔 늘 켜져 있어 아무 뜻이 없었다(5차).
  /// 아직 한 번도 열지 않았을 때만 보여 새 기능이 있다고 알린다.
  bool phraseSettingsSeen = true;
  static const phraseSettingsSeenKey = 'parrokit.home.phrase_settings_seen.v1';

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

  /// 켜면 내 차례에 마이크를 누르지 않아도 스스로 듣고, 통과하면 스스로 넘어간다(5차).
  bool autoListen = true;
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

  /// 목소리가 없다고 이미 알린 언어. 자동으로 돌 때마다 되풀이하지 않는다(5차 367).
  final _noVoiceTold = <String>{};
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

  int totalXp = 0;
  bool xpReady = false;
  List<String> customPhrases = [];
  Set<String>? enabledRoutineIds;
  List<DefaultConversationSentence> mySentences = [];
  // 문장 상세도 같은 자리에 쌓는다(5차).
  String get xpKey => speakingXpKey(widget.accountId);
  String get countListenKey =>
      'parrokit.speaking.count_listen.v1.${widget.accountId}';
  String get gapKey => 'parrokit.speaking.gap_seconds.v1.${widget.accountId}';
  String get autoListenKey =>
      'parrokit.speaking.auto_listen.v1.${widget.accountId}';
  String get phrasesKey =>
      'parrokit.speaking.phrases.v1.${widget.accountId}.${widget.language}';
  int get level => levelForXp(totalXp);

  /// 다른 화면이 XP를 주면 머리의 막대도 따라 읽는다(5차 566).
  void _onXpChanged() {
    if (mounted) unawaited(loadXp());
  }

  Future<void> loadXp() async {
    try {
      // 새 자리(v2)에서 읽는다. 처음이면 옛 값에서 옮겨 적는다(5차 566).
      final loadedXp = await loadParrotXp(widget.accountId);
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        totalXp = loadedXp;
        gapSeconds = (prefs.getDouble(gapKey) ?? _defaultGapSeconds).clamp(
            _SpeakingSettingsDialog.minGap, _SpeakingSettingsDialog.maxGap);
        countListen = prefs.getBool(countListenKey) ?? true;
        autoListen = prefs.getBool(autoListenKey) ?? true;
        phraseSettingsSeen = prefs.getBool(phraseSettingsSeenKey) ?? false;
        xpReady = true;
      });
    } catch (_) {
      if (mounted) setState(() => xpReady = true);
    }
  }

  Future<void> showSpeakingSettings() async {
    final next = await whilePaused(
        () => showDialog<({double gap, bool countListen, bool autoListen})>(
              context: context,
              builder: (context) => _SpeakingSettingsDialog(
                  initialGap: gapSeconds,
                  initialCountListen: countListen,
                  initialAutoListen: autoListen),
            ));
    if (!mounted || next == null) return;
    setState(() {
      gapSeconds = next.gap;
      countListen = next.countListen;
      autoListen = next.autoListen;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(gapKey, next.gap);
      await prefs.setBool(countListenKey, next.countListen);
      await prefs.setBool(autoListenKey, next.autoListen);
    } catch (_) {/* 저장하지 못해도 이번 실행에서는 바뀐 설정을 쓴다. */}
  }

  /// 성취 XP를 준다(5차 566).
  ///
  /// 전에는 따라 말하기 한 번마다 0.1~1 XP를 줬다. 레벨 하나에 100번이
  /// 들어 막대가 움직이지 않았고, 같은 행동이 친밀도·크래커·XP를 한꺼번에
  /// 받아 어느 주머니가 무엇을 세는지 알 수 없었다.
  ///
  /// 이제 XP는 한 번만 생기는 일에만 붙는다 - 하루 첫 연습, 하루 목표
  /// 달성, 문장 단계 상승. 반복은 크래커가 맡는다.
  Future<bool> awardXp(int gain, {String? reason}) async {
    if (gain <= 0) return true;
    final previous = totalXp;
    final next = await addParrotXp(widget.accountId, gain);
    if (next == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('XP를 저장하지 못했어요. 다시 시도해 주세요.')));
      }
      return false;
    }
    if (!mounted) return false;
    setState(() {
      totalXp = next;
      xpReady = true;
    });
    final leveled = levelForXp(next) > levelForXp(previous);
    final head = reason == null ? '' : '$reason · ';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(leveled
          ? '$head+$gain XP · 앵무새가 Lv.${levelForXp(next)} 이 됐어요'
          : '$head+$gain XP'),
      duration: const Duration(seconds: 2),
    ));
    return true;
  }

  /// 앵무새가 말할 수 있는 문장: 내가 저장·추가한 문장만(5차, 기본 문장 없앰).
  List<DefaultConversationSentence> get allSentences =>
      mySentences.where((s) => s.language == widget.language).toList();

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
        // 기본으로 주던 예시 문장을 없앤 뒤로는(5차) 처음 켠 사람이 바로 이
        // 상태를 본다. 무엇을 해야 하는지와 누르면 된다는 것을 함께 말한다.
        if (routineDefaults.isEmpty && customPhrases.isEmpty)
          '여기를 눌러 따라 말할 문장을 추가해 보세요.',
      ];
  String get phrase => phrases[phraseIndex % phrases.length];

  Future<void> loadRoutineSettings() async {
    try {
      final activities = await SentenceActivityStore.loadAll(widget.accountId);
      final mine = await MySentenceStore.load(widget.accountId);
      final enabled = mine
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
    parrotXpRevision.addListener(_onXpChanged);
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
      if (!available) {
        // 전에는 아무 말 없이 돌아와서, 앵무새가 입만 벙긋하고 소리가 안 나는
        // 것처럼 보였다(5차 367). 문장 상세의 읽어 주기와 같은 말로 알린다.
        if (mounted && _noVoiceTold.add(locale)) showToast(ttsNoVoiceHint);
        return;
      }
      if (!mounted) return;
      await tts.stop();
      await tts.setLanguage(locale);
      ttsSpeaking = true;
      speakingSentenceId = sentenceForPhrase(text)?.id;
      typedFrom = typedTo = 0;
      typing.value = 0;
      voiceTyping = true;
      if (mounted) setState(() {});
      // 이어 듣던 클립이 있으면 멈춘다. 둘이 겹쳐 울리지 않게(5차, 사용자 요청).
      await AudioFocus.instance.claim();
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
    if (!foreground || !visible || paused || sheetOpen) {
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
    // parrotSpeakCount는 읽는 곳이 없어 적기를 멈춘다(5차 566).
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
  /// 창이 떠 있는 동안 앵무새를 멈췄다가, 닫히면 원래대로 돌린다.
  Future<T?> whilePaused<T>(Future<T?> Function() open) async {
    if (mounted) setState(() => sheetOpen = true);
    syncPlayback();
    try {
      return await open();
    } finally {
      if (mounted) {
        setState(() => sheetOpen = false);
        syncPlayback();
      }
    }
  }

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
    final picked = await whilePaused(() => showAppSheet<int>(
          context: context,
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
                        // 문장 친밀도. 예전엔 'Lv.2'만 있어 바로 위 내 레벨(Lv.1)과
                        // 헷갈렸다. 문장 탭과 같이 단계 이름을 붙인다(5차).
                        final affinity = sentence == null
                            ? null
                            : affinityOf(activities[sentence.id] ??
                                const SentenceActivity());
                        return ListTile(
                          selected: i == current,
                          leading: i == current
                              ? const Icon(Icons.volume_up_rounded)
                              : Text('${i + 1}'),
                          title: Text(list[i]),
                          subtitle:
                              sentence == null || sentence.translation.isEmpty
                                  ? null
                                  : Text(sentence.translation,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                          trailing: affinity == null
                              ? null
                              : Text('Lv.${affinity.level} ${affinity.name}',
                                  style: context.texts.labelMedium),
                          onTap: () => Navigator.pop(context, i),
                        );
                      })),
            ]),
          ),
        ));
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
      final practicedSentence = sentenceForPhrase(phrase);
      var gain = 0;
      final notes = <String>[];
      if (practicedSentence != null) {
        final result = await SentenceActivityStore.incrementPractice(
          widget.accountId,
          practicedSentence.id,
          score: score,
        );
        gain += result.xp;
        if (result.leveledTo != null) notes.add('문장 단계가 올랐어요');
        if (result.dayFull) notes.add(sentenceDayFullMessage);
      }
      // 하루 첫 연습에 한 번만 준다.
      if (await markFirstPracticeToday(widget.accountId)) {
        gain += firstPracticeXp;
        notes.add('오늘 첫 연습');
      }
      await awardXp(gain, reason: notes.isEmpty ? null : notes.first);
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
  /// 말할 문장이 없으면 안내를 누른 것이므로 문장 추가로 간다(5차).
  Future<void> openPhraseDetails() async {
    if (!hasSpeakablePhrase) {
      await addPhrase();
      return;
    }
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
      result = await whilePaused(() => addSentenceFlow(
            context,
            accountId: widget.accountId,
            language: widget.language,
          ));
      if (result != null) await loadRoutineSettings();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(sentenceSaveFailedMessage)));
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
    if (!phraseSettingsSeen) {
      setState(() => phraseSettingsSeen = true);
      unawaited(SharedPreferences.getInstance()
          .then((prefs) => prefs.setBool(phraseSettingsSeenKey, true))
          .catchError((_) => false));
    }
    final action = await whilePaused(() => showDialog<String>(
          context: context,
          builder: (context) => _PhraseSettingsDialog(
            accountId: widget.accountId,
            initialLanguage: widget.language,
            mySentences: mySentences,
            initialEnabled: {
              for (final sentence in mySentences)
                sentence.id: activities[sentence.id]?.routineEnabled ?? true,
            },
          ),
        ));
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
    parrotXpRevision.removeListener(_onXpChanged);
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
                    value: xpInLevelOf(totalXp) / xpForLevel(level),
                    minHeight: 5,
                    color: palette.primary,
                    backgroundColor: palette.surfaceAlt)),
            const SizedBox(height: 6),
            Align(
                alignment: Alignment.centerRight,
                child: Text(
                    xpReady
                        ? '${xpInLevelOf(totalXp)} / ${xpForLevel(level)} XP'
                        : 'XP 불러오는 중…',
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
                top: 16,
                child: Column(children: [
                  _GameMenuButton(
                      label: soundOn ? '소리 끄기' : '소리 켜기',
                      shortLabel: '소리',
                      icon: soundOn
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      selected: soundOn,
                      onTap: () => setSound(!soundOn)),
                  const SizedBox(height: 6),
                  _GameMenuButton(
                      key: const ValueKey('add-phrase'),
                      label: '문장 추가',
                      shortLabel: '문장 추가',
                      icon: Icons.add_comment_rounded,
                      onTap: addPhrase),
                  const SizedBox(height: 6),
                  _GameMenuButton(
                      key: const ValueKey('phrase-settings'),
                      label: '문장 설정',
                      shortLabel: '문장 설정',
                      icon: Icons.tune_rounded,
                      badge: !phraseSettingsSeen,
                      onTap: showPhraseSettings),
                  const SizedBox(height: 6),
                  _GameMenuButton(
                      label: '말하기 설정',
                      shortLabel: '말하기 설정',
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
              SpeechPracticeView(
                  key: ValueKey('${widget.language}-$phraseIndex-$phraseRound'),
                  phrase: phrase,
                  localeId: _speechLocales[widget.language] ?? 'en_US',
                  recognizer: recognizer,
                  enabled: !completingResponse && !paused,
                  reduceMotion: reduceMotion,
                  onAttempt: recordAttempt,
                  onBeforeStart: interruptParrot,
                  onComplete: completeRepeat,
                  // 앵무새가 말을 마치고 내 차례가 된 뒤에만 스스로 듣는다.
                  autoListen: autoListen && awaitingResponse),
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

class _SpeakingSettingsDialog extends StatefulWidget {
  const _SpeakingSettingsDialog(
      {required this.initialGap,
      required this.initialCountListen,
      required this.initialAutoListen});
  final double initialGap;
  final bool initialCountListen;
  final bool initialAutoListen;

  static const minGap = 0.5;
  static const maxGap = 10.0;

  @override
  State<_SpeakingSettingsDialog> createState() =>
      _SpeakingSettingsDialogState();
}

class _SpeakingSettingsDialogState extends State<_SpeakingSettingsDialog> {
  late double gap = widget.initialGap;
  late bool countListen = widget.initialCountListen;
  late bool autoListen = widget.initialAutoListen;

  @override
  Widget build(BuildContext context) {
    final palette = HomeTokens.of(context);
    return AlertDialog(
      // 버튼 툴팁·도움말의 '말하기 설정'과 같게(5차). 예전 '설정'.
      title: const Text('말하기 설정'),
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
                key: const ValueKey('auto-listen-switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('자동으로 듣기',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                    '내 차례가 되면 마이크를 누르지 않아도 듣고, 잘 따라 하면 다음 문장으로 넘어가요.',
                    style: context.texts.bodySmall),
                value: autoListen,
                onChanged: (value) => setState(() => autoListen = value)),
            SwitchListTile(
                key: const ValueKey('count-listen-switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('듣기 횟수 기록',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(countListenHint,
                    style: context.texts.bodySmall),
                value: countListen,
                onChanged: (value) => setState(() => countListen = value)),
          ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(
            onPressed: () => Navigator.pop(context,
                (gap: gap, countListen: countListen, autoListen: autoListen)),
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

  List<DefaultConversationSentence> get visibleSentences =>
      widget.mySentences.where((s) => s.language == language).toList();

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
            // 전에는 여기 자물쇠와 '그 외 언어는 준비 중'이 붙어 있었다.
            // 바로 위 고르개가 영어·일본어·중국어를 다 내주는데 그 밑에서
            // 잠겼다고 하니 어긋나 보였고, 고르개 안에 이미 '새 언어는 이
            // 목록에 계속 추가할 수 있어요.'가 있어 같은 말이 두 번이었다.
            // 고르개를 쓰는 다른 네 화면에는 이 줄이 없다(5차 481).
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                  child: Text('앵무새가 말할 문장',
                      style: context.texts.bodyLarge.copyWith(color: ink))),
              // 숫자만 '50 / 50'이라 무엇을 세는지 알 수 없었다(5차).
              // 홈의 '앵무새 62/63'과 같이 무엇의 수인지 적는다.
              Text(
                  routineCountLabel(
                      on: visibleSentences.where(isOn).length,
                      total: visibleSentences.length),
                  key: const ValueKey('routine-count'),
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
                  onPressed: () =>
                      Navigator.pop(context, _PhraseSettingsDialog.addAction),
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
  // 도움말 버튼이 레벨 옆에 있는데 레벨·XP 설명이 없었다(5차). 맨 위에 둔다.
  static const _sections = <(String, List<(IconData, String, String)>)>[
    (
      '레벨',
      [
        (
          Icons.trending_up_rounded,
          'XP와 레벨',
          '따라 말하기를 하면 점수만큼 XP가 쌓여요(100점이면 1 XP). 10 XP마다 레벨이 올라요.'
        ),
      ]
    ),
    (
      '왼쪽 버튼',
      [
        (
          Icons.volume_up_rounded,
          '소리',
          '앵무새 목소리를 켜고 꺼요. 듣기와 함께 켜져 있어야 문장을 읽어 줘요.'
        ),
        (Icons.add_comment_rounded, '문장 추가', '내가 연습할 문장을 직접 넣어요.'),
        (Icons.tune_rounded, '문장 설정', '앵무새가 말할 문장을 골라요. 체크하면 바로 반영돼요.'),
        (Icons.settings_rounded, '말하기 설정', '말하기 간격과 듣기 횟수를 기록할지 정해요.'),
      ]
    ),
    (
      '아래 줄',
      [
        (
          Icons.record_voice_over_rounded,
          '따라 말하기',
          '앵무새가 말한 문장을 마이크로 따라 말하고 점수를 받아요.'
        ),
        (Icons.headphones_rounded, '듣기', '켜면 앵무새가 문장을 소리 내어 읽어 줘요.'),
        (Icons.skip_next_rounded, '이전 · 다음', '앞뒤 문장으로 넘어가요.'),
        (Icons.pause_rounded, '멈춤 · 재생', '앵무새 말하기를 잠시 멈추거나 다시 시작해요.'),
        // 버튼에 적히는 말 그대로 적는다(5차). 190에서 '아무 순서'로 바꿨다가
        // 화면 라벨('랜덤')과 어긋나 되돌렸다.
        (Icons.repeat_rounded, '재생 순서', '순서대로, 하나 반복, 랜덤으로 바꿔요.'),
        (Icons.queue_music_rounded, '목록', '문장 목록에서 바로 골라요.'),
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
      this.shortLabel,
      required this.icon,
      this.selected = false,
      this.badge = false,
      required this.onTap});
  final String label;

  /// 아이콘 아래에 적을 짧은 이름. 아래 조작 줄처럼 글자를 함께 보여 준다(5차).
  /// 전에는 아이콘만 있어서 눌러 보기 전에는 무엇인지 알 수 없었다.
  final String? shortLabel;
  final IconData icon;
  final bool selected;
  final bool badge;
  // 아래 아이콘 줄(40pt)이 사라져 크기는 44pt 하나만 남았다. 이름을 아래
  // 붙이면서 네 칸이 조작 줄에 가려, 40pt로 줄였다(5차).
  static const double dimension = 40;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = HomeTokens.of(context);
    final button = _buildButton(context, palette);
    final name = shortLabel;
    if (name == null) return button;
    return SizedBox(
      width: 62,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        button,
        const SizedBox(height: 2),
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: context.texts.labelSmall.copyWith(
            fontSize: 10,
            color: selected ? palette.primary : palette.muted,
            height: 1.1,
          ),
        ),
      ]),
    );
  }

  Widget _buildButton(BuildContext context, HomeTokens palette) {
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
                      size: 23, color: selected ? Colors.white : palette.muted),
                  if (badge)
                    Positioned(
                        key: const ValueKey('menu-badge'),
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

/// 말풍선이 그려지는 영역(테스트에서도 쓴다, 5차 324).
///
/// 긴 문장은 [_GrowthPainter.speechMaxLines] 줄에서 멈추므로, 200자든
/// 600자든 말풍선 높이가 더 늘지 않는다.
Rect stageBubbleRect(Size size, String phrase) {
  final speech = _GrowthPainter._speechPainter(size, phrase);
  final bubbleWidth = speech.width + 24;
  final left = ((size.width - bubbleWidth) / 2)
      .clamp(4.0, math.max(4.0, size.width - bubbleWidth - 4));
  final rect =
      Rect.fromLTWH(left.toDouble(), 16, bubbleWidth, speech.height + 16);
  speech.dispose();
  return rect;
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

  /// 말풍선에 보여 줄 수 있는 줄 수. 문장을 200자까지 쓸 수 있게 하면서
  /// 긴 문장이 무대를 다 덮었다(5차 324). 넘치면 '…'로 줄이고, 말풍선을
  /// 누르면 상세에서 다 볼 수 있다.
  static const speechMaxLines = 4;

  static TextPainter _speechPainter(Size size, String phrase) => TextPainter(
      text: TextSpan(text: phrase, style: _speechStyle),
      textDirection: TextDirection.ltr,
      maxLines: speechMaxLines,
      ellipsis: '…')
    ..layout(maxWidth: size.width * 0.58);

  /// 말풍선이 그려지는 영역. 터치 판정에도 같이 쓴다.
  static Rect bubbleRect(Size size, String phrase) =>
      stageBubbleRect(size, phrase);

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
          textDirection: TextDirection.ltr,
          maxLines: speechMaxLines,
          ellipsis: '…')
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
                // 큰 글자 설정에서 '따라 …', '순서…'로 잘렸다(5차). 잘라 내는 대신
                // 칸에 맞게 줄여 낱말 전체를 보인다.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label,
                      maxLines: 1,
                      style: context.texts.labelSmall.copyWith(
                          color: selected ? palette.primary : palette.muted,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// 문장 설정 창의 '켠 문장 N / 전체'. 숫자만 두면 무엇의 수인지 알 수 없다(5차).
String routineCountLabel({required int on, required int total}) =>
    on == total && total > 0 ? '$total개 모두 켜짐' : '켠 문장 $on / $total';
