// 말하면 인식된 만큼 문장 색이 채워지고, 충분히 비슷하면 완료하는 '따라 말하기' 위젯.
//
// 홈 무대에만 있던 것을 문장 상세에서도 쓰려고 따로 뺐다(5차). 화면은 그대로다.
//
// [autoListen]이면 버튼을 누르지 않아도 된다(5차, 사용자 요청). 내 차례가 되면
// 스스로 듣기 시작하고, 통과선을 넘긴 뒤 말이 멎으면 끝내고 다음으로 넘어간다.
// 못 맞춘 채 끝나면 정해진 횟수만큼 혼자 다시 듣는다. 그 뒤에는 멈춰서 기다린다.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/theme/app_radius.dart';
import 'package:parrokit/core/shared/theme/app_tokens.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/core/speech/phrase_recognizer.dart';
import 'package:parrokit/core/speech/speech_match.dart';

/// 위젯이 시도 하나가 끝났을 때 넘겨주는 결과.
/// 따라 말할 문장을 작은 글씨로 보여 줄지(5차 325).
///
/// 한 화면에 담기는 길이를 넘으면 글자를 줄인다. 자르지는 않는다. 따라
/// 말하려면 문장을 다 봐야 한다.
bool compactPracticePhrase(String phrase) => phrase.trim().length > 80;

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
class SpeechPracticeView extends StatefulWidget {
  const SpeechPracticeView(
      {super.key,
      required this.phrase,
      required this.localeId,
      required this.recognizer,
      required this.enabled,
      required this.reduceMotion,
      required this.onAttempt,
      required this.onBeforeStart,
      required this.onComplete,
      this.autoListen = false});
  final String phrase;
  final String localeId;
  final PhraseRecognizer recognizer;
  final bool enabled;
  final bool reduceMotion;

  /// 버튼을 누르지 않아도 스스로 듣고, 통과하면 스스로 넘어간다.
  final bool autoListen;
  final void Function(double? score) onComplete;

  /// 마이크를 켜거나 체크를 누르기 직전에 부른다. 앵무새가 말하는 중이면 멈추게 한다.
  final VoidCallback onBeforeStart;

  /// 시도가 끝날 때마다 알린다. 점수는 인식 없이 직접 넘긴 경우 null.
  final void Function(PracticeAttemptResult result) onAttempt;
  @override
  State<SpeechPracticeView> createState() => SpeechPracticeViewState();
}

class SpeechPracticeViewState extends State<SpeechPracticeView> {
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

  /// 스스로 듣기까지 기다리는 시간. 앵무새 소리가 완전히 멎은 뒤 켜려고 둔다.
  static const _autoStartDelay = Duration(milliseconds: 500);

  /// 못 맞춘 채 끝났을 때 스스로 다시 듣기까지 기다리는 시간.
  static const _autoRetryDelay = Duration(milliseconds: 900);

  /// 통과한 뒤 '잘했어요'를 보여 주고 다음으로 넘어가기까지 기다리는 시간.
  static const _autoAdvanceDelay = Duration(milliseconds: 1200);

  /// 스스로 다시 듣는 최대 횟수. 끝없이 듣고 있지 않게 막는다.
  static const _autoRetryLimit = 2;

  Timer? autoTimer;
  int autoTries = 0;

  /// 스스로 듣는 중에 마이크를 눌러 멈췄다. 다시 누를 때까지는 혼자 켜지 않는다.
  bool autoStopped = false;

  /// 이번 시도를 이미 완료로 넘겼다. 다시 말하기 전까지는 또 넘기지 않는다.
  ///
  /// 전에는 체크를 누를 때마다 같은 점수로 XP와 연습 수가 또 올라갔다
  /// (5차, 사용자 신고).
  bool completed = false;

  /// 한 번 끝낸 뒤 처음으로 되돌린다. 다음 시도는 0점부터 시작한다.
  void resetAttempt() {
    passTimer?.cancel();
    attemptStart = null;
    setState(() {
      score = 0;
      heard = '';
      level = 0;
      message = null;
    });
  }

  /// 체크를 눌렀을 때. 아직 말하지 않았으면 아무 일도 하지 않는다.
  void completeByHand() {
    autoTimer?.cancel();
    widget.onBeforeStart();
    if (completed && score == 0 && attemptStart == null) {
      // 방금 완료하고 아직 다시 말하지 않았다. 또 올려 주지 않는다.
      setState(() => message = '한 번 더 말하고 눌러 주세요.');
      return;
    }
    // 이미 기록된 시도(말하고 끝난 경우)는 다시 기록하지 않는다.
    if (attemptStart != null || score == 0) {
      finishAttempt(success: true, manual: true);
    }
    final earned = score > 0 ? score : null;
    unawaited(stopListening());
    completed = true;
    resetAttempt();
    widget.onComplete(earned);
  }

  /// 지금 스스로 듣고 넘어가도 되는지.
  bool get canAutoListen => widget.autoListen && widget.enabled && !autoStopped;

  /// 지금까지 들은 것을 버리고 처음부터 다시 듣는다('다시 하기').
  ///
  /// 자동으로 듣다 보면 엉뚱한 소리가 먼저 들어갈 수 있어서, 마이크 버튼
  /// 대신 이 버튼을 둔다(5차, 사용자 요청).
  Future<void> restartListening() async {
    autoTimer?.cancel();
    passTimer?.cancel();
    autoStopped = false;
    autoTries = 0;
    completed = false;
    if (listening) {
      await stopListening();
      if (!mounted) return;
    }
    setState(() {
      score = 0;
      heard = '';
      message = null;
    });
    await toggleListening(byHand: true);
  }

  @override
  void initState() {
    super.initState();
    scheduleAutoListen(_autoStartDelay);
  }

  @override
  void didUpdateWidget(covariant SpeechPracticeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && listening) unawaited(stopListening());
    // 내 차례가 되면(autoListen이 켜지면) 스스로 듣기 시작한다.
    if (widget.autoListen && !oldWidget.autoListen) autoStopped = false;
    scheduleAutoListen(_autoStartDelay);
  }

  /// 듣고 있지도, 이미 예약돼 있지도 않으면 스스로 듣기를 예약한다.
  void scheduleAutoListen(Duration delay) {
    if (!canAutoListen || listening || (autoTimer?.isActive ?? false)) return;
    if (autoTries > _autoRetryLimit) return;
    autoTimer = Timer(delay, () {
      if (!mounted || !canAutoListen || listening) return;
      unawaited(toggleListening());
    });
  }

  Future<void> toggleListening({bool byHand = false}) async {
    if (!widget.enabled) return;
    autoTimer?.cancel();
    if (listening) {
      // 손으로 멈추면 혼자 다시 켜지 않는다. 마이크를 다시 누르면 이어서 한다.
      if (byHand) autoStopped = true;
      return stopListening();
    }
    if (byHand) {
      autoStopped = false;
      autoTries = 0;
    }
    widget.onBeforeStart();
    setState(() {
      score = 0;
      message = null;
      heard = '';
    });
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
    completed = false;
    autoTries++;
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
    final next = speechMatchScore(widget.phrase, text);
    setState(() {
      // 내가 말한 것이 그대로 보여야 어디가 틀렸는지 안다(5차, 사용자 요청).
      heard = text;
      score = math.max(score, next);
    });
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
    final auto = canAutoListen;
    setState(() => message =
        auto ? '잘했어요! 다음 문장으로 넘어가요.' : '잘했어요! 체크를 누르면 다음 문장으로 넘어가요.');
    if (!auto) return;
    autoTimer?.cancel();
    autoTimer = Timer(_autoAdvanceDelay, () {
      if (!mounted || !canAutoListen) return;
      final earned = score > 0 ? score : null;
      completed = true;
      resetAttempt();
      widget.onComplete(earned);
    });
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
    final passed = score >= speechPassScore;
    // 못 맞춘 채 끝났으면 정해진 횟수까지는 혼자 다시 듣는다.
    final retry = !passed && canAutoListen && autoTries <= _autoRetryLimit;
    setState(() {
      listening = false;
      level = 0;
      if (passed) {
        message = canAutoListen
            ? '잘했어요! 다음 문장으로 넘어가요.'
            : '잘했어요! 체크를 누르면 다음 문장으로 넘어가요.';
      } else if (retry) {
        message = '다시 한번 말해볼까요?';
      } else if (canAutoListen) {
        message = '다시 하기를 누르면 또 들을게요. 체크를 누르면 다음 문장으로 넘어가요.';
      } else {
        message = '다시 한번 말해볼까요?';
      }
    });
    if (retry) scheduleAutoListen(_autoRetryDelay);
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
    autoTimer?.cancel();
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
          // 긴 문장(200자까지 쓸 수 있다)은 글자를 줄여 담는다. 큰 글씨
          // 그대로면 열 줄이 넘어 마이크 줄이 화면 밖으로 밀렸다(5차 325).
          style: compactPracticePhrase(widget.phrase)
              ? context.texts.titleMedium.copyWith(height: 1.45)
              : context.texts.headlineSmall.copyWith(height: 1.5)),
      if (score > 0) ...[
        const SizedBox(height: 8),
        Text('${(score * 100).round()}점',
            key: const ValueKey('speech-score'),
            style: context.texts.titleLarge
                .copyWith(color: score >= speechPassScore ? active : idle)),
      ],
      const SizedBox(height: 16),
      Row(children: [
        if (widget.autoListen)
          // 자동으로 듣는 동안에는 켜고 끄는 버튼이 필요 없다. 잘못 들어갔을 때
          // 처음부터 다시 하는 버튼만 둔다(5차, 사용자 요청).
          Semantics(
              label: '처음부터 다시 말하기',
              button: true,
              child: IconButton.filledTonal(
                  key: const ValueKey('restart-practice'),
                  tooltip: '다시 하기',
                  onPressed: widget.enabled ? restartListening : null,
                  style: IconButton.styleFrom(
                      backgroundColor: palette.primary.withValues(alpha: 0.12),
                      foregroundColor: active),
                  icon: const Icon(Icons.refresh_rounded)))
        else
          Semantics(
              label: listening ? '음성 인식 중지' : '마이크를 누르고 따라 말하기',
              button: true,
              child: IconButton.filledTonal(
                  key: const ValueKey('preview-microphone'),
                  tooltip: listening ? '음성 인식 중지' : '따라 말하기 시작',
                  onPressed: widget.enabled
                      ? () => toggleListening(byHand: true)
                      : null,
                  style: IconButton.styleFrom(
                      backgroundColor: listening
                          ? active
                          : palette.primary.withValues(alpha: 0.12),
                      foregroundColor: listening ? palette.surface : active),
                  icon: Icon(
                      listening ? Icons.stop_rounded : Icons.mic_rounded))),
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
            onPressed: widget.enabled ? completeByHand : null,
            icon: Icon(Icons.check_circle_rounded, color: active, size: 30)),
      ]),
      if (heard.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(children: [
            Text('내가 말한 것',
                style: context.texts.labelSmall.copyWith(color: idle)),
            const SizedBox(height: 2),
            Text(heard,
                key: const ValueKey('speech-heard'),
                textAlign: TextAlign.center,
                style:
                    context.texts.bodyReading.copyWith(color: palette.ink)),
          ]),
        ),
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
