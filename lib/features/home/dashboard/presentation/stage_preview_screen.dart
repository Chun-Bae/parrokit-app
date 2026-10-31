import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parrokit/core/content/default_conversation_sentences.dart';
import 'package:parrokit/core/content/learning_languages.dart';
import 'package:parrokit/core/content/my_sentence_store.dart';
import 'package:parrokit/core/content/sentence_activity_store.dart';
import 'package:parrokit/core/shared/widgets/learning_language_picker.dart';
import 'nest_preview.dart';

enum _SpeakingMode { automatic, repeat }

/// 앵무새의 자동 말하기와 따라 말하기 흐름을 확인하는 시안.
/// 기존 경로 호환을 위해 화면 이름은 유지한다.
class StagePreviewScreen extends StatefulWidget {
  const StagePreviewScreen(
      {super.key,
      this.embedded = false,
      this.language = '영어',
      this.nickname = '나',
      this.accountId = 'guest',
      this.onPracticeCompleted});
  final String nickname;
  final String accountId;
  final bool embedded;
  final String language;
  final Future<void> Function()? onPracticeCompleted;
  @override
  State<StagePreviewScreen> createState() => _StagePreviewScreenState();
}

class _StagePreviewScreenState extends State<StagePreviewScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final animation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
      animationBehavior: AnimationBehavior.preserve)
    ..addStatusListener(onSpeechStatus);
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
  bool ttsReady = false;
  bool ttsSpeaking = false;
  bool pendingAdvance = false;

  /// 음성 진행(읽은 위치)에 맞춰 말풍선 글자를 보여주는 상태.
  /// 단어 단위로 오는 진행 값을 짧게 보간해 한 글자씩 나오는 것처럼 보이게 한다.
  bool voiceTyping = false;
  double typedFrom = 0;
  double typedTo = 0;
  late final typing = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 260));
  final _ttsLocaleAvailable = <String, bool>{};
  static const _ttsLocales = {'영어': 'en-US', '일본어': 'ja-JP', '중국어': 'zh-CN'};
  int phraseIndex = 0;
  int totalXp = 0;
  bool xpReady = false;
  List<String> customPhrases = [];
  Set<String>? enabledRoutineIds;
  List<DefaultConversationSentence> mySentences = [];
  String get xpKey => 'parrokit.speaking.xp.v1.${widget.accountId}';
  String get phrasesKey =>
      'parrokit.speaking.phrases.v1.${widget.accountId}.${widget.language}';
  int get level => totalXp ~/ 10 + 1;

  Future<void> loadXp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        totalXp = math.max(0, prefs.getInt(xpKey) ?? 0);
        xpReady = true;
      });
    } catch (_) {
      if (mounted) setState(() => xpReady = true);
    }
  }

  Future<bool> awardXp() async {
    final key = xpKey;
    try {
      final prefs = await SharedPreferences.getInstance();
      final next = math.max(0, prefs.getInt(key) ?? 0) + 1;
      if (!await prefs.setInt(key, next)) throw StateError('XP save failed');
      if (!mounted) return false;
      setState(() {
        totalXp = next;
        xpReady = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(next % 10 == 0
            ? '+1 XP · Lv.${next ~/ 10 + 1} 레벨 업!'
            : '따라 말하기 완료 · +1 XP'),
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

  static final samples = {
    for (final language in availableLearningLanguages)
      language.label: defaultSentencesFor(language.label)
          .map((sentence) => sentence.text)
          .toList(growable: false),
  };

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
      tts.setErrorHandler((_) => handleTtsDone());
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
    if (voiceTyping) {
      typedFrom = typedTo = 1;
      typing.value = 1;
    }
    if (!mounted || !pendingAdvance) return;
    pendingAdvance = false;
    finishPhrase();
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
    stopTts();
    if (pendingAdvance) {
      pendingAdvance = false;
      finishPhrase();
    }
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
    } catch (_) {/* 파일이 없으면 코드 그림을 표시한다. */}
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
    if (awaitingResponse || pendingAdvance) {
      animation.stop();
    } else if (!animation.isAnimating) {
      animation.forward(from: animation.isCompleted ? 0 : animation.value);
      unawaited(speakPhrase());
    }
  }

  void onSpeechStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    // 말풍선 시간이 끝났어도 음성이 아직 나오고 있으면 끝날 때까지 기다린다.
    if (ttsSpeaking) {
      pendingAdvance = true;
      return;
    }
    finishPhrase();
  }

  void finishPhrase() {
    if (!mounted) return;
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
        phraseIndex = (phraseIndex + 1) % phrases.length;
      }
    });
    syncPlayback();
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

  Future<void> completeRepeat() async {
    if (!awaitingResponse || completingResponse) return;
    setState(() => completingResponse = true);
    try {
      final saved = await awardXp();
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
        phraseIndex = (phraseIndex + 1) % phrases.length;
      });
      animation.reset();
    } finally {
      if (mounted) {
        setState(() => completingResponse = false);
        syncPlayback();
      }
    }
  }

  Future<void> addPhrase() async {
    final added = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const _AddPhraseDialog(),
    );
    if (!mounted || added == null) return;
    try {
      await MySentenceStore.add(
        widget.accountId,
        language: widget.language,
        text: added,
      );
      await loadRoutineSettings();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('문장을 저장하지 못했어요. 다시 시도해주세요.')));
      }
      return;
    }
    if (!mounted) return;
    final index = phrases.indexOf(added);
    setState(() {
      if (index >= 0) phraseIndex = index;
      awaitingResponse = false;
    });
    pendingAdvance = false;
    stopTts();
    animation.reset();
    syncPlayback();
  }

  Future<void> showPhraseSettings() => showDialog<void>(
        context: context,
        builder: (context) => _PhraseSettingsDialog(
          initialLanguage: widget.language,
          phrasesByLanguage: samples,
          customPhrases: [
            ...mySentences
                .where((sentence) => sentence.language == widget.language)
                .map((sentence) => sentence.text),
            ...customPhrases,
          ],
        ),
      );

  void previewFeature() {
    unawaited(HapticFeedback.selectionClick());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SentenceActivityStore.revision.removeListener(handleRoutineChanged);
    stopTts();
    typing.dispose();
    animation.dispose();
    birdAnimation.dispose();
    nestSprite?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const muted = Color(0xFF61758D);
    const accent = Color(0xFF4F6EAF);
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
                      style: const TextStyle(
                          color: Color(0xFF24364F),
                          fontSize: 19,
                          fontWeight: FontWeight.w800))),
              Text('Lv.$level',
                  style: const TextStyle(
                      color: Color(0xFF42766C),
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 10),
            ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                    value: totalXp % 10 / 10,
                    minHeight: 5,
                    color: const Color(0xFF91BEB0),
                    backgroundColor: const Color(0xFFE1EAF0))),
            const SizedBox(height: 6),
            Align(
                alignment: Alignment.centerRight,
                child: Text(xpReady ? '${totalXp % 10} / 10 XP' : 'XP 불러오는 중…',
                    style: const TextStyle(color: muted, fontSize: 11))),
          ])),
      Container(
          height: 320,
          width: double.infinity,
          color: const Color(0xFFF3F8FD),
          child: Stack(children: [
            Positioned.fill(
                bottom: 62,
                child: Semantics(
                    label: '앵무새가 이야기해요. $phrase',
                    child: AnimatedBuilder(
                        animation: Listenable.merge(
                            [animation, birdAnimation, typing]),
                        builder: (context, _) {
                          final moving = !reduceMotion && !paused;
                          // 음성이 이어지는 동안은 말풍선 시간이 끝나도 사라지지 않게 붙잡는다.
                          final holdBubble = voiceTyping && ttsSpeaking;
                          final phase = awaitingResponse
                              ? 0.6
                              : holdBubble
                                  ? math.min(animation.value, 0.6)
                                  : animation.value;
                          return CustomPaint(
                              painter: _GrowthPainter(
                                  typedFraction:
                                      voiceTyping ? typedFraction : null,
                                  phase: phase,
                                  birdPhase: birdAnimation.value,
                                  sprite: nestSprite,
                                  phrase: phrase,
                                  animate: moving));
                        }))),
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
                      label: '학습 기록',
                      icon: Icons.calendar_month_rounded,
                      onTap: previewFeature),
                ])),
            Positioned(
                right: 8,
                top: 16,
                child: Column(children: [
                  _GameMenuButton(
                      label: '캐릭터 정보',
                      icon: Icons.badge_rounded,
                      onTap: previewFeature),
                  const SizedBox(height: 7),
                  _GameMenuButton(
                      label: '꾸미기',
                      icon: Icons.checkroom_rounded,
                      badge: true,
                      onTap: previewFeature),
                  const SizedBox(height: 7),
                  _GameMenuButton(
                      label: '보관함',
                      icon: Icons.backpack_rounded,
                      onTap: previewFeature),
                  const SizedBox(height: 7),
                  _GameMenuButton(
                      label: '도전 과제',
                      icon: Icons.emoji_events_rounded,
                      badge: true,
                      onTap: previewFeature),
                  const SizedBox(height: 7),
                  _GameMenuButton(
                      label: '설정',
                      icon: Icons.settings_rounded,
                      onTap: previewFeature),
                ])),
            Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: SizedBox(
                    height: 40,
                    child:
                        ListView(scrollDirection: Axis.horizontal, children: [
                      _GameMenuButton(
                          dimension: 40,
                          label: '자동 모드',
                          icon: Icons.autorenew_rounded,
                          selected: mode == _SpeakingMode.automatic,
                          onTap: () => changeMode(_SpeakingMode.automatic)),
                      const SizedBox(width: 4),
                      _GameMenuButton(
                          dimension: 40,
                          label: '따라 말하기 모드',
                          icon: Icons.record_voice_over_rounded,
                          selected: mode == _SpeakingMode.repeat,
                          onTap: () => changeMode(_SpeakingMode.repeat)),
                      const SizedBox(width: 4),
                      _GameMenuButton(
                          dimension: 40,
                          label: listenMode ? '듣기 모드 끄기' : '듣기 모드 켜기',
                          icon: Icons.headphones_rounded,
                          selected: listenMode,
                          onTap: () => setListenMode(!listenMode)),
                      const SizedBox(width: 4),
                      _GameMenuButton(
                          dimension: 40,
                          label: '쇼츠 학습',
                          icon: Icons.smart_display_rounded,
                          onTap: previewFeature),
                      const SizedBox(width: 4),
                      _GameMenuButton(
                          dimension: 40,
                          label: '공유 영상',
                          icon: Icons.groups_rounded,
                          onTap: previewFeature),
                      const SizedBox(width: 4),
                      _GameMenuButton(
                          dimension: 40,
                          label: paused ? '말하기 재개' : '말하기 일시 정지',
                          icon: paused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                          onTap: () {
                            setState(() => paused = !paused);
                            syncPlayback();
                          }),
                    ]))),
          ])),
      if (awaitingResponse)
        Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: _SpeechWavePreview(
                key: ValueKey('${widget.language}-$phraseIndex'),
                phrase: phrase,
                enabled: !completingResponse && !paused,
                reduceMotion: reduceMotion,
                onComplete: completeRepeat)),
      const SizedBox(height: 16),
      const SizedBox(height: 16),
    ]);
    final theme = ThemeData.light(useMaterial3: true).copyWith(
        colorScheme: const ColorScheme.light(
            primary: accent, onPrimary: Colors.white, surface: Colors.white),
        textTheme: ThemeData.light().textTheme.apply(
            fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily));
    return Theme(
        data: theme,
        child: widget.embedded
            ? Container(color: const Color(0xFFF3F8FD), child: content)
            : Scaffold(
                backgroundColor: const Color(0xFFF3F8FD),
                appBar: AppBar(title: const Text('앵무새와 말하기')),
                body: SingleChildScrollView(
                    padding: EdgeInsets.only(
                        bottom: MediaQuery.paddingOf(context).bottom + 120),
                    child: content)));
  }
}

class _AddPhraseDialog extends StatefulWidget {
  const _AddPhraseDialog();

  @override
  State<_AddPhraseDialog> createState() => _AddPhraseDialogState();
}

class _AddPhraseDialogState extends State<_AddPhraseDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController();
  }

  void submit() {
    final phrase = controller.text.trim();
    if (phrase.isNotEmpty) Navigator.pop(context, phrase);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('문장 추가'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(hintText: '연습할 문장을 입력하세요'),
          onSubmitted: (_) => submit(),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('취소')),
          FilledButton(onPressed: submit, child: const Text('추가')),
        ],
      );
}

/// 음성 인식 연결 전, 마이크를 눌러 색이 채워지는 모습을 확인하는 시안.
class _SpeechWavePreview extends StatefulWidget {
  const _SpeechWavePreview(
      {super.key,
      required this.phrase,
      required this.enabled,
      required this.reduceMotion,
      required this.onComplete});
  final String phrase;
  final bool enabled;
  final bool reduceMotion;
  final VoidCallback onComplete;
  @override
  State<_SpeechWavePreview> createState() => _SpeechWavePreviewState();
}

class _SpeechWavePreviewState extends State<_SpeechWavePreview>
    with SingleTickerProviderStateMixin {
  late final preview =
      AnimationController(vsync: this, duration: const Duration(seconds: 4));
  @override
  void didUpdateWidget(covariant _SpeechWavePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) preview.stop();
    if (widget.reduceMotion && preview.isAnimating) {
      preview.stop();
      preview.value = 1;
    }
  }

  void playPreview() {
    if (!widget.enabled) return;
    if (widget.reduceMotion) {
      preview.value = 1;
    } else {
      preview.forward(from: 0);
    }
  }

  @override
  void dispose() {
    preview.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: preview,
      builder: (context, _) {
        const active = Color(0xFF6D9890);
        final letters = widget.phrase.characters.toList();
        final highlighted = (preview.value * letters.length).floor();
        return Column(children: [
          Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: letters.take(highlighted).join(),
                    style: const TextStyle(color: active)),
                TextSpan(
                    text: letters.skip(highlighted).join(),
                    style: const TextStyle(color: Color(0xFF607482))),
              ]),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 21, fontWeight: FontWeight.w600, height: 1.5)),
          const SizedBox(height: 16),
          Row(children: [
            Semantics(
                label: '음파 효과 미리보기. 실제 음성 인식은 아직 연결되지 않았어요.',
                button: true,
                child: IconButton.filledTonal(
                    key: const ValueKey('preview-microphone'),
                    tooltip: '음파 효과 미리보기',
                    onPressed: widget.enabled ? playPreview : null,
                    style: IconButton.styleFrom(
                        backgroundColor: preview.isAnimating
                            ? active
                            : const Color(0xFFE1EBE8),
                        foregroundColor:
                            preview.isAnimating ? Colors.white : active),
                    icon: const Icon(Icons.mic_rounded))),
            const SizedBox(width: 12),
            Expanded(
                child: SizedBox(
                    height: 48,
                    child: LayoutBuilder(builder: (context, constraints) {
                      final count =
                          math.max(1, (constraints.maxWidth / 7).floor());
                      return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(count, (i) {
                            final colored = i < preview.value * count;
                            final base = 8 + (math.sin(i * 1.7).abs() * 23);
                            final pulse = preview.isAnimating
                                ? 0.6 +
                                    math
                                            .sin(preview.value * math.pi * 12 +
                                                i)
                                            .abs() *
                                        0.4
                                : 1.0;
                            return Container(
                                width: 3,
                                height: base * pulse,
                                decoration: BoxDecoration(
                                    color: colored
                                        ? active
                                        : const Color(0xFFDDE6EB),
                                    borderRadius: BorderRadius.circular(2)));
                          }));
                    }))),
            const SizedBox(width: 12),
            IconButton(
                key: const ValueKey('complete-repeat'),
                tooltip: '따라 말하기 완료',
                onPressed: widget.enabled ? widget.onComplete : null,
                icon: const Icon(Icons.check_circle_rounded,
                    color: active, size: 30)),
          ]),
        ]);
      });
}

class _PhraseSettingsDialog extends StatefulWidget {
  const _PhraseSettingsDialog({
    required this.initialLanguage,
    required this.phrasesByLanguage,
    required this.customPhrases,
  });

  final String initialLanguage;
  final Map<String, List<String>> phrasesByLanguage;
  final List<String> customPhrases;

  @override
  State<_PhraseSettingsDialog> createState() => _PhraseSettingsDialogState();
}

class _PhraseSettingsDialogState extends State<_PhraseSettingsDialog> {
  late String language;
  final enabledByLanguage = <String, Set<String>>{};

  @override
  void initState() {
    super.initState();
    language = widget.initialLanguage;
  }

  List<String> get visiblePhrases => [
        ...(widget.phrasesByLanguage[language] ?? const <String>[]),
        if (language == widget.initialLanguage) ...widget.customPhrases,
      ];

  Set<String> get enabled =>
      enabledByLanguage.putIfAbsent(language, () => visiblePhrases.toSet());

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF24364F);
    const muted = Color(0xFF6C8092);
    const active = Color(0xFF6D9890);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 570),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(children: [
            Row(children: [
              const Expanded(
                  child: Text('말하기 설정',
                      style: TextStyle(
                          color: ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w800))),
              IconButton(
                  tooltip: '닫기',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: muted)),
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
                    color: const Color(0xFFF1F5F7),
                    borderRadius: BorderRadius.circular(12)),
                child: const Row(children: [
                  Icon(Icons.lock_outline_rounded, size: 16, color: muted),
                  SizedBox(width: 7),
                  Text('그 외 언어는 준비 중',
                      style: TextStyle(
                          color: muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ])),
            const SizedBox(height: 18),
            Row(children: [
              const Expanded(
                  child: Text('앵무새가 말할 문장',
                      style: TextStyle(
                          color: ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w800))),
              Text('${enabled.length} / ${visiblePhrases.length}',
                  style: const TextStyle(
                      color: muted, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 8),
            Expanded(
                child: ListView.separated(
                    itemCount: visiblePhrases.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final phrase = visiblePhrases[index];
                      final selected = enabled.contains(phrase);
                      return Material(
                          color: selected
                              ? const Color(0xFFEAF3F0)
                              : const Color(0xFFF7F9FA),
                          borderRadius: BorderRadius.circular(13),
                          child: CheckboxListTile(
                              dense: true,
                              value: selected,
                              activeColor: active,
                              checkColor: Colors.white,
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              title: Text(phrase,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: ink,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              onChanged: (value) => setState(() {
                                    if (value == true) {
                                      enabled.add(phrase);
                                    } else if (enabled.length > 1) {
                                      enabled.remove(phrase);
                                    }
                                  })));
                    })),
            const SizedBox(height: 14),
            Row(children: [
              IconButton.filledTonal(
                  tooltip: '문장 추가',
                  onPressed: () {},
                  icon: const Icon(Icons.add_rounded)),
              const SizedBox(width: 10),
              Expanded(
                  child: FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: active,
                          minimumSize: const Size.fromHeight(48)),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('적용',
                          style: TextStyle(fontWeight: FontWeight.w800)))),
            ]),
          ]),
        ),
      ),
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
      this.dimension = 44,
      required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final bool badge;
  final double dimension;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: dimension,
        child: Semantics(
          label: label,
          selected: selected,
          button: true,
          child: Tooltip(
            message: label,
            excludeFromSemantics: true,
            child: Material(
              color: selected ? const Color(0xFF6D9890) : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                      color: selected
                          ? const Color(0xFF6D9890)
                          : const Color(0xFFDDE8ED))),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                  onTap: onTap,
                  child: Stack(alignment: Alignment.center, children: [
                    Icon(icon,
                        size: dimension <= 40 ? 21 : 23,
                        color:
                            selected ? Colors.white : const Color(0xFF718B98)),
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
                                  borderRadius: BorderRadius.circular(2)))),
                  ])),
            ),
          ),
        ),
      );
}

class _GrowthPainter extends CustomPainter {
  _GrowthPainter(
      {this.birdPhase = 0,
      this.sprite,
      required this.phase,
      required this.phrase,
      required this.animate,
      this.typedFraction});
  final double birdPhase;
  final ui.Image? sprite;
  final double phase;
  final String phrase;
  final bool animate;

  /// null이면 애니메이션 시간으로, 값이 있으면 음성 진행 비율로 글자를 보여준다.
  final double? typedFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    canvas.save();
    canvas.translate(0, 30);
    NestScenePainter(phase: birdPhase, joy: 0, meals: 0, sprite: sprite)
        .paint(canvas, Size(size.width, size.height - 30));
    canvas.restore();
    // 등장 → 한 글자씩 표시 → 잠깐 유지 → 사라짐. 위치와 크기는 고정한다.
    if (phrase.isNotEmpty && (!animate || (phase >= 0.08 && phase < 0.88))) {
      const speechStyle = TextStyle(
          color: Color(0xFF253C34), fontSize: 13, fontWeight: FontWeight.w800);
      final maxWidth = size.width * 0.58;
      final fullSpeech = TextPainter(
          text: TextSpan(text: phrase, style: speechStyle),
          textDirection: TextDirection.ltr)
        ..layout(maxWidth: maxWidth);
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
      final bubbleWidth = fullSpeech.width + 24;
      final left = ((size.width - bubbleWidth) / 2)
          .clamp(4.0, math.max(4.0, size.width - bubbleWidth - 4));
      final bubble = Rect.fromLTWH(
          left.toDouble(), 16, bubbleWidth, fullSpeech.height + 16);
      final opacity = !animate
          ? 1.0
          : math.min(((phase - 0.08) / 0.05).clamp(0.0, 1.0),
              ((0.88 - phase) / 0.06).clamp(0.0, 1.0));
      canvas.saveLayer(bubble.inflate(10),
          Paint()..color = Colors.white.withValues(alpha: opacity));
      paint.color = const Color(0xFFFFFBE3);
      canvas.drawRRect(
          RRect.fromRectAndRadius(bubble, const Radius.circular(12)), paint);
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
