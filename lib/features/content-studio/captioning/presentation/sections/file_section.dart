// ============================================================================
// lib/features/content-studio/captioning/presentation/sections/file_section.dart
// ============================================================================
//
// [역할]
// 파일 선택 섹션 위젯.
// 영상 파일 선택, 제거, 인라인 재생, 오디오 파형 추출 UI.
//
// [레이어]
// Presentation Layer > Sections
// ============================================================================

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';

import 'package:video_player/video_player.dart';

import '../widgets/file_hero_card.dart';
import '../widgets/stt_confirm_dialog.dart';
import '../providers/captioning_provider.dart';
import 'segments_section.dart';

/// 파일 선택 섹션.
class FileSection extends StatefulWidget {
  const FileSection({super.key, required this.vm});

  final CaptioningProvider vm;

  @override
  State<FileSection> createState() => _FileSectionState();
}

class _FileSectionState extends State<FileSection> {
  VideoPlayerController? _vp;
  bool _vpReady = false;
  String? _lastInitializedPath;

  @override
  void initState() {
    super.initState();
    widget.vm.addListener(_onVmChanged);
    _onVmChanged();
  }

  @override
  void didUpdateWidget(FileSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vm != widget.vm) {
      oldWidget.vm.removeListener(_onVmChanged);
      widget.vm.addListener(_onVmChanged);
    }
  }

  @override
  void dispose() {
    widget.vm.removeListener(_onVmChanged);
    _vp?.dispose();
    super.dispose();
  }

  void _onVmChanged() {
    final path = widget.vm.picked?.path;
    if (path == null) {
      if (_lastInitializedPath != null) {
        _vp?.dispose();
        _vp = null;
        _vpReady = false;
        _lastInitializedPath = null;
        if (mounted) setState(() {});
      }
      return;
    }
    if (path != _lastInitializedPath) {
      _lastInitializedPath = path;
      _initPlayer(path);
    }
  }

  Future<void> _initPlayer(String path) async {
    try {
      await _vp?.dispose();
      final c = VideoPlayerController.file(File(path));
      await c.initialize();
      await c.seekTo(Duration.zero);
      widget.vm.durationCtl.text = c.value.duration.inMilliseconds.toString();

      c.addListener(() {
        if (!mounted) return;
        final v = c.value;
        final done =
            v.isInitialized && !v.isPlaying && v.position >= v.duration;
        if (done) setState(() {});
      });

      if (mounted) {
        setState(() {
          _vp = c;
          _vpReady = false;
        });
      }
    } catch (e) {
      AppLogger.e('[Captioning][Player] 백그라운드 재생 초기화 실패', error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FileHeroCard(
          picked: vm.picked,
          onPick: vm.pickFromSandbox,
          onRemove: () {
            _stopInline();
            vm.removePicked();
          },
          onAddToSandbox: () async {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.video,
              allowMultiple: false,
            );
            if (result != null && result.files.isNotEmpty) {
              vm.pickFromSandbox();
            }
          },
          onPickFromPhotos: vm.pickFromPhotos,
          thumb: vm.thumb,
          isPlayingInline: _vpReady,
          playerController: _vp,
          onPlayInline: _playInline,
          onToggleInline: _toggleInline,
          onStopInline: _stopInline,
          onReopenLast: () {},
          onReopenFile: vm.pickFromSandbox,
          onReopenPhotos: vm.pickFromPhotos,
          onSttRequest: () => showSttConfirmDialog(context, vm: vm),
          lastSourceLabel: '파일',
          waveformData: vm.waveformData,
          waveformLoading: vm.waveformLoading,
          isVideoLoading: vm.isVideoLoading,
          segmentsWidget: SegmentsSection(
            vm: vm,
            playerController: _vp,
          ),
          segmentForms: vm.segmentForms,
          onOverlayRangeChanged: (range) {
            vm.updateSegmentRange(
              range.segmentIndex,
              startMs: range.startMs,
              endMs: range.endMs,
            );
            vm.validateSegmentAt(range.segmentIndex);
          },
          onOverlayStartAdjusted: vm.adjustSegmentStartConstrained,
          onOverlayEndAdjusted: vm.adjustSegmentEndConstrained,
        ),
      ],
    );
  }

  Future<void> _playInline() async {
    if (_vp == null) {
      showToast('재생할 파일이 준비되지 않았습니다.');
      return;
    }
    setState(() => _vpReady = true);
    await _vp!.play();
  }

  void _toggleInline() {
    if (_vp == null) return;
    setState(() {
      _vpReady = true;
      _vp!.value.isPlaying ? _vp!.pause() : _vp!.play();
    });
  }

  Future<void> _stopInline() async {
    await _vp?.pause();
    if (!mounted) return;
    setState(() {
      _vpReady = false;
    });
  }
}
