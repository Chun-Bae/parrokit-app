// 네이티브 플레이어 시험 화면 (5차 1단계). 개발 빌드에서만 열린다.
//
// 새 플레이어가 영상을 띄우고 재생·멈춤·되감기·속도를 제대로 받는지 눈으로
// 보려고 둔다. 클립 플레이어를 바꾸는 것은 4단계라, 그전까지 여기서 본다.

import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:parrokit/core/shared/player/native_player.dart';
import 'package:parrokit/core/shared/theme/components/typography/app_texts_theme.dart';
import 'package:parrokit/data/local/app_database.dart';

class NativePlayerTestScreen extends StatefulWidget {
  const NativePlayerTestScreen({super.key});

  @override
  State<NativePlayerTestScreen> createState() => _NativePlayerTestScreenState();
}

class _NativePlayerTestScreenState extends State<NativePlayerTestScreen> {
  final NativePlayerController _player = NativePlayerController();
  bool _loaded = false;
  String _path = '';

  @override
  void initState() {
    super.initState();
    _player.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  /// 보관함에 저장된 클립들. 넘겨 가며 틀어 본다.
  List<Clip> _clips = const [];
  int _index = 0;

  Future<String> _pathOf(Clip clip) async {
    final source = clip.filePath;
    if (source.isEmpty || source.startsWith('/')) return source;
    final docs = await getApplicationDocumentsDirectory();
    return '${docs.path}/$source';
  }

  Future<void> _loadOnce() async {
    if (_loaded) return;
    _loaded = true;
    final db = context.read<AppDatabase>();
    final clips = await db.select(db.clips).get();
    if (!mounted) return;
    setState(() => _clips = clips);
    await _loadAt(0);
  }

  Future<void> _loadAt(int index) async {
    if (_clips.isEmpty) return;
    final clip = _clips[index % _clips.length];
    final path = await _pathOf(clip);
    if (!mounted) return;
    setState(() {
      _index = index % _clips.length;
      _path = path;
    });
    if (path.isEmpty || !File(path).existsSync()) return;
    await _player.load(path);
  }

  @override
  void dispose() {
    _player.removeListener(_onChanged);
    _player.dispose();
    super.dispose();
  }

  String _clock(Duration value) {
    final minutes = value.inMinutes;
    final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final state = _player.state;
    // 플랫폼 뷰가 만들어진 뒤에야 명령이 닿는다.
    if (_player.isAttached) unawaitedLoad();

    return Scaffold(
      appBar: AppBar(title: const Text('네이티브 플레이어 시험')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SizedBox(
          height: 320,
          child: NativePlayerSurface(controller: _player),
        ),
        const SizedBox(height: 12),
        const SizedBox(height: 8),
        Text(
          _clips.isEmpty
              ? ''
              : '${_index + 1}/${_clips.length} · '
                  '${_clips[_index].title} · $_path',
          style: context.texts.labelSmall,
          maxLines: 3,
        ),
        const SizedBox(height: 8),
        if (!nativePlayerSupported)
          const Text('이 기기에는 아직 없어요. iOS에서만 돼요.')
        else if (_loaded && _path.isEmpty)
          const Text('보관함에 클립이 없어요.')
        else if (state.errorMessage != null)
          Text(state.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error))
        else
          Text(
            '${state.ready ? "준비됨" : "읽는 중"} · '
            '${_clock(state.position)} / ${_clock(state.duration)} · '
            '${state.speed}배',
            style: context.texts.bodyMedium,
          ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton(
            key: const ValueKey('native-player-play'),
            onPressed: state.playing ? _player.pause : _player.play,
            child: Text(state.playing ? '멈춤' : '재생'),
          ),
          OutlinedButton(
            onPressed: () => _player.seek(Duration.zero),
            child: const Text('처음으로'),
          ),
          OutlinedButton(
            onPressed: () => _player.seek(
                state.position + const Duration(seconds: 2)),
            child: const Text('2초 뒤로'),
          ),
          OutlinedButton(
            onPressed: () =>
                _player.setSpeed(state.speed == 1.0 ? 1.5 : 1.0),
            child: Text(state.speed == 1.0 ? '1.5배' : '1배'),
          ),
          OutlinedButton(
            key: const ValueKey('native-player-next-clip'),
            onPressed: _clips.isEmpty ? null : () => _loadAt(_index + 1),
            child: const Text('다음 클립'),
          ),
        ]),
      ]),
    );
  }

  void unawaitedLoad() {
    // build 안에서 기다리지 않고 한 번만 부른다.
    _loadOnce();
  }
}
