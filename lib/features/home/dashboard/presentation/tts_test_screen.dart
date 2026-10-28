import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'package:parrokit/core/content/default_conversation_sentences.dart';
import 'package:parrokit/core/content/learning_languages.dart';

/// flutter_tts 동작을 확인하기 위한 임시 테스트 화면.
class TtsTestScreen extends StatefulWidget {
  const TtsTestScreen({super.key});

  @override
  State<TtsTestScreen> createState() => _TtsTestScreenState();
}

class _TtsTestScreenState extends State<TtsTestScreen> {
  static const _localeByLanguage = {
    '영어': 'en-US',
    '일본어': 'ja-JP',
    '중국어': 'zh-CN',
  };

  final FlutterTts tts = FlutterTts();
  late final TextEditingController controller;
  String language = '영어';
  double rate = 0.45;
  double pitch = 1.0;
  bool speaking = false;
  String status = '준비 중';

  List<DefaultConversationSentence> get samples =>
      defaultSentencesFor(language);

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: samples.first.text);
    unawaited(setup());
  }

  Future<void> setup() async {
    try {
      tts.setStartHandler(() => _setSpeaking(true, '재생 중'));
      tts.setCompletionHandler(() => _setSpeaking(false, '완료'));
      tts.setCancelHandler(() => _setSpeaking(false, '중지됨'));
      tts.setErrorHandler((message) => _setSpeaking(false, '오류: $message'));
      await tts.awaitSpeakCompletion(false);
      if (mounted) setState(() => status = '준비 완료');
    } catch (e) {
      if (mounted) setState(() => status = '초기화 실패: $e');
    }
  }

  void _setSpeaking(bool value, String message) {
    if (!mounted) return;
    setState(() {
      speaking = value;
      status = message;
    });
  }

  Future<void> speak() async {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    try {
      await tts.stop();
      final locale = _localeByLanguage[language] ?? 'en-US';
      final available = await tts.isLanguageAvailable(locale);
      if (available != true) {
        if (mounted) setState(() => status = '$locale 음성이 기기에 없어요');
        return;
      }
      await tts.setLanguage(locale);
      await tts.setSpeechRate(rate);
      await tts.setPitch(pitch);
      await tts.speak(text);
    } catch (e) {
      if (mounted) setState(() => status = '재생 실패: $e');
    }
  }

  Future<void> stop() async {
    try {
      await tts.stop();
    } catch (_) {}
  }

  @override
  void dispose() {
    unawaited(tts.stop());
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TTS 테스트')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final item in availableLearningLanguages)
                ChoiceChip(
                  label: Text(item.label),
                  selected: language == item.label,
                  onSelected: (_) => setState(() {
                    language = item.label;
                    controller.text = samples.first.text;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: '읽을 문장',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final sentence in samples)
                ActionChip(
                  label: Text(sentence.text),
                  onPressed: () => setState(
                    () => controller.text = sentence.text,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('속도 ${rate.toStringAsFixed(2)}'),
          Slider(
            value: rate,
            min: 0.1,
            max: 1.0,
            onChanged: (v) => setState(() => rate = v),
          ),
          Text('음높이 ${pitch.toStringAsFixed(2)}'),
          Slider(
            value: pitch,
            min: 0.5,
            max: 2.0,
            onChanged: (v) => setState(() => pitch = v),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: speak,
                  icon: const Icon(Icons.volume_up_rounded),
                  label: const Text('읽기'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: speaking ? stop : null,
                icon: const Icon(Icons.stop_rounded),
                label: const Text('중지'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('상태: $status'),
        ],
      ),
    );
  }
}
