import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

/// Idle bird by kiranironhide.ironhide, CC BY 4.0.
/// Source and license: assets/characters/idle_bird/SOURCE.md.
class IdleBirdPreview extends StatefulWidget {
  const IdleBirdPreview({super.key, required this.playing});
  final bool playing;

  @override
  State<IdleBirdPreview> createState() => _IdleBirdPreviewState();
}

class _IdleBirdPreviewState extends State<IdleBirdPreview> {
  Artboard? artboard;
  StateMachineController? controller;
  bool failed = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final file = await RiveFile.asset(
          'assets/characters/idle_bird/idle_bird.riv',
          loadCdnAssets: false);
      if (!mounted) return;
      final board = file.artboardByName('New Artboard');
      if (board == null) throw StateError('Missing bird artboard');
      final machine =
          StateMachineController.fromArtboard(board, 'State Machine 1');
      if (machine == null) throw StateError('Missing bird animation');
      board.addController(machine);
      machine.isActive = widget.playing;
      setState(() {
        artboard = board;
        controller = machine;
      });
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  @override
  void didUpdateWidget(covariant IdleBirdPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    controller?.isActive = widget.playing;
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (failed) {
      return const Center(
          child: Text('애니메이션을 불러오지 못했어요.\n아래에서 기존 앵무새로 바꿀 수 있어요.',
              textAlign: TextAlign.center));
    }
    final board = artboard;
    if (board == null) return const Center(child: CircularProgressIndicator());
    return Semantics(
      label: 'Idle Bird 움직임 시안',
      child: Rive(artboard: board, fit: BoxFit.contain),
    );
  }
}
