// 글을 읽어 주는 단추 둘(듣기·반복 듣기). 문장 상세와 단어 상세가 같이 쓴다.
//
// 전에는 문장 상세에만 듣기가 있었고, 단어에는 소리가 아예 없었다(5차 320).
// 규칙(언어별 음성, 반복 간격, 다른 소리가 나면 멈추기)을 화면마다 따로 적으면
// 한 곳만 고쳐지므로 여기 하나로 둔다.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'package:parrokit/core/shared/utils/audio_focus.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';

/// 앱이 아는 언어의 기기 음성 코드.
const Map<String, String> ttsLocales = {
  '영어': 'en-US',
  '일본어': 'ja-JP',
  '중국어': 'zh-CN',
};

/// 기기에서 소리를 낼 수 없을 때(음성 기능 준비 실패).
const String ttsNotReadyHint = '이 기기에서는 읽어 줄 수 없어요.';

/// 그 언어의 음성이 기기에 깔려 있지 않을 때.
const String ttsNoVoiceHint = '이 언어의 음성이 기기에 없어요.';

/// 한 번 읽고 다시 읽기까지 쉬는 시간.
const Duration speakRepeatGap = Duration(milliseconds: 700);

class SpeakControls extends StatefulWidget {
  const SpeakControls({
    super.key,
    required this.text,
    required this.language,
    this.speakKey = const ValueKey('speak-text'),
    this.repeatKey = const ValueKey('repeat-text'),
    this.speechRate = 0.45,
    this.showRepeat = true,
    this.onListened,
  });

  /// 읽어 줄 글.
  final String text;

  /// 앱에서 쓰는 언어 이름('영어', '일본어'…). 모르면 영어로 읽는다.
  final String language;

  final Key speakKey;
  final Key repeatKey;
  final double speechRate;

  /// 반복 단추를 함께 둘지. 복습 카드처럼 한 번만 듣는 자리에서는 끈다(5차 329).
  final bool showRepeat;

  /// 한 번 끝까지 읽어 준 뒤에 부른다. 듣기 횟수를 적는 데 쓴다(5차 338,
  /// 사용자 신고: 문장 상세에서 들어도 '듣기 0회'였다). 홈 무대와 같은 규칙
  /// (끝까지 들은 것만 센다)이라 중간에 멈추면 세지 않는다.
  final VoidCallback? onListened;

  @override
  State<SpeakControls> createState() => _SpeakControlsState();
}

class _SpeakControlsState extends State<SpeakControls> {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  bool _speaking = false;
  bool _repeating = false;
  Timer? _repeatTimer;

  @override
  void initState() {
    super.initState();
    // 다른 소리가 나면 읽기도 멈춘다. 켜 두고, 내가 틀 때만 나를 뺀다.
    AudioFocus.instance.registerBackground(_stopSpeaking);
    unawaited(_setup());
  }

  /// 다른 소리가 날 때 불린다. 읽기와 반복을 모두 멈춘다.
  Future<void> _stopSpeaking() async {
    _repeatTimer?.cancel();
    _repeatTimer = null;
    if (mounted && _repeating) setState(() => _repeating = false);
    await _tts.stop();
  }

  Future<void> _setup() async {
    try {
      _tts.setStartHandler(() => _setSpeaking(true));
      _tts.setCompletionHandler(() {
        _setSpeaking(false);
        widget.onListened?.call();
        _scheduleRepeat();
      });
      _tts.setCancelHandler(() => _setSpeaking(false));
      _tts.setErrorHandler((_) => _setSpeaking(false));
      await _tts.setSpeechRate(widget.speechRate);
      _ready = true;
    } catch (_) {/* 소리를 쓸 수 없으면 눌렀을 때 알린다. */}
  }

  void _setSpeaking(bool value) {
    if (mounted) setState(() => _speaking = value);
  }

  void _scheduleRepeat() {
    if (!_repeating || !mounted) return;
    _repeatTimer?.cancel();
    _repeatTimer = Timer(speakRepeatGap, () {
      if (!_repeating || !mounted) return;
      unawaited(_speakOnce(claimFocus: false));
    });
  }

  /// 듣기 단추. 읽는 중이면 멈춘다(반복 중이었으면 반복도 끈다).
  Future<void> _toggleSpeak() async {
    if (!_ready) {
      showToast(ttsNotReadyHint);
      return;
    }
    if (_speaking || _repeating) {
      await _stopRepeat();
      await _tts.stop();
      return;
    }
    await _speakOnce();
  }

  /// 반복 단추.
  Future<void> _toggleRepeat() async {
    if (!_ready) {
      showToast(ttsNotReadyHint);
      return;
    }
    if (_repeating) {
      await _stopRepeat();
      return;
    }
    setState(() => _repeating = true);
    await _speakOnce();
  }

  Future<void> _stopRepeat() => _stopSpeaking();

  /// 한 번 읽는다. 반복으로 이어 읽을 때는 소리 차례를 다시 뺏지 않는다
  /// (뺏으면 내 반복까지 멈춘다).
  Future<void> _speakOnce({bool claimFocus = true}) async {
    if (!_ready) return;
    final text = widget.text.trim();
    if (text.isEmpty) return;
    try {
      final locale = ttsLocales[widget.language.trim()] ?? 'en-US';
      if (await _tts.isLanguageAvailable(locale) != true) {
        if (mounted) showToast(ttsNoVoiceHint);
        await _stopRepeat();
        return;
      }
      await _tts.setLanguage(locale);
      // 내가 등록해 둔 정지 콜백은 빼고 다른 소리만 멈춘다.
      if (claimFocus) {
        await AudioFocus.instance.claim(except: _stopSpeaking);
      }
      await _tts.speak(text);
    } catch (_) {
      _setSpeaking(false);
    }
  }

  @override
  void dispose() {
    _repeatTimer?.cancel();
    AudioFocus.instance.unregisterBackground(_stopSpeaking);
    unawaited(_tts.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // 켜진 것을 또렷하게 보여 준다. 기본 isSelected 색은 밝은 시트 위에서
    // 꺼진 것과 거의 같아 보였다(5차 320).
    ButtonStyle onStyle() => IconButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          key: widget.speakKey,
          tooltip: _speaking && !_repeating ? '듣기 멈추기' : '듣기',
          onPressed: _toggleSpeak,
          isSelected: _speaking && !_repeating,
          style: _speaking && !_repeating ? onStyle() : null,
          icon: const Icon(Icons.volume_up_rounded),
          selectedIcon: const Icon(Icons.graphic_eq_rounded),
        ),
        if (widget.showRepeat) ...[
          const SizedBox(width: 4),
          IconButton.filledTonal(
            key: widget.repeatKey,
            tooltip: _repeating ? '반복 멈추기' : '반복 듣기',
            onPressed: _toggleRepeat,
            isSelected: _repeating,
            style: _repeating ? onStyle() : null,
            icon: const Icon(Icons.repeat_rounded),
            selectedIcon: const Icon(Icons.repeat_on_rounded),
          ),
        ],
      ],
    );
  }
}
