// ============================================================================
// lib/features/content-studio/captioning/presentation/providers/mixins/edit_file_mixin.dart
// ============================================================================
//
// [역할]
// 파일 선택/제거 로직 mixin.
//
// [레이어]
// Presentation Layer > Provider > Mixin
// ============================================================================

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:parrokit/core/shared/utils/show_toast.dart';

import '../../../data/adapters/video_picker_files.dart';
import '../../../data/adapters/video_picker_gallery.dart';
import '../../../data/ports/video_picker_port.dart';
import '../../../data/services/audio_to_video.dart';
import '../../../data/services/file_staging_service.dart';
import '../../../data/services/video_meta_service.dart';
import '../../../data/usecases/extract_duration_usecase.dart';
import '../../../data/usecases/extract_thumbnail_usecase.dart';
import '../../../data/usecases/pick_video_usecase.dart';

/// 파일 선택/제거 mixin.
mixin EditFileMixin on ChangeNotifier {
  // 의존성 (추상 getter - 메인 ViewModel에서 구현)
  FileStagingService get staging;
  AudioToVideoService get audioToVideo;
  ExtractThumbnailUseCase get extractThumb;
  ExtractDurationUseCase get extractDuration;
  PickVideoUseCase get pickVideo;
  TextEditingController get durationCtl;

  // ─────────────────────────────────────────────────────────────────
  // 상태
  // ─────────────────────────────────────────────────────────────────
  PlatformFile? _picked;
  PlatformFile? get picked => _picked;

  /// mp4 변환 전 원본 경로 (STT용).
  /// mp3 등 오디오 파일은 mp4로 변환하기 전 경로를 보존하여
  /// STT 시 이중 변환(mp3→mp4→wav) 없이 원본을 직접 사용합니다.
  String? _originalStagedPath;
  String? get originalStagedPath => _originalStagedPath;

  Uint8List? _thumb;
  Uint8List? get thumb => _thumb;

  bool _isVideoLoading = false;
  bool get isVideoLoading => _isVideoLoading;

  List<double>? _waveformData;
  List<double>? get waveformData => _waveformData;

  bool _waveformLoading = false;
  bool get waveformLoading => _waveformLoading;

  String? _tempPcmPath;

  /// 파형 추출 요청 번호. 영상을 바꾸면 올라간다.
  /// 앞선 요청이 늦게 끝나도 결과를 버리기 위한 것이다.
  int _waveformRequestId = 0;

  // ─────────────────────────────────────────────────────────────────
  // 파일 선택
  // ─────────────────────────────────────────────────────────────────

  /// 로컬 파일 시스템에서 영상 파일을 선택하고 Staging 영역으로 복사합니다.
  Future<void> pickFromSandbox() async {
    final picked = await pickVideo(PickSource.files);
    if (picked == null) return;
    final (rawPath, pf) = picked;
    final stagedPath =
        await staging.stageFromPath(rawPath, suggestedName: pf.name);
    await _afterPick(path: stagedPath, name: pf.name, size: pf.size);
  }

  /// 갤러리(Phoots)에서 영상 파일을 선택하고 Staging 영역으로 복사합니다.
  Future<void> pickFromPhotos() async {
    final picked = await pickVideo(PickSource.gallery);
    if (picked == null) return;
    final (rawPath, pf) = picked;
    final stagedPath =
        await staging.stageFromPath(rawPath, suggestedName: pf.name);
    await _afterPick(path: stagedPath, name: pf.name, size: pf.size);
  }

  Future<void> _afterPick({
    required String path,
    required String name,
    required int size,
  }) async {
    _isVideoLoading = true;
    notifyListeners();

    // 원본 경로 보존 (STT에서 이중 변환 방지용)
    _originalStagedPath = path;

    String effectivePath = path;
    try {
      effectivePath = await audioToVideo.ensureMp4(path);
    } catch (e) {
      _isVideoLoading = false;
      notifyListeners();
      showToast('오디오를 영상으로 변환 중 오류: $e');
      return;
    }

    _picked = PlatformFile(name: name, size: size, path: effectivePath);
    _thumb = null;

    await _setThumb(effectivePath);
    final ms = await _probeDurationMs(effectivePath);
    if (ms != null) {
      durationCtl.text = ms.toString();
    }
    _isVideoLoading = false;
    notifyListeners();

    // 비디오 로딩 후 파형 추출 (1회 수행)
    _extractWaveform(effectivePath);
  }

  Future<void> setExistingFile(String relPath) async {
    _isVideoLoading = true;
    notifyListeners();

    final docsDir = await getApplicationDocumentsDirectory();
    final absPath =
        relPath.startsWith('/') ? relPath : '${docsDir.path}/$relPath';

    final file = File(absPath);
    if (!await file.exists()) {
      _isVideoLoading = false;
      notifyListeners();
      showToast('기존 파일을 찾을 수 없습니다.');
      return;
    }

    final stat = await file.stat();
    final name = absPath.split('/').last;

    _picked = PlatformFile(name: name, size: stat.size, path: absPath);
    _thumb = null;

    await _setThumb(absPath);
    _isVideoLoading = false;
    notifyListeners();

    // 편집 모드 로드 후 파형 추출 (1회 수행)
    _extractWaveform(absPath);
  }

  void removePicked() {
    final p = _picked?.path;
    _picked = null;
    _thumb = null;
    _originalStagedPath = null;
    _waveformData = null;
    _waveformLoading = false;
    // 아직 돌고 있는 파형 추출이 있으면 그 결과를 버리게 한다. 번호를 올리지
    // 않으면 영상을 지운 뒤에 지운 영상의 파형이 뒤늦게 올라온다.
    _waveformRequestId++;
    _cleanupTempPcm();

    if (p != null && staging.isInStaging(p)) {
      staging.discard(p);
    }
    notifyListeners();
  }

  Future<void> _setThumb(String path) async {
    final bytes = await extractThumb(path);
    _thumb = bytes;
    notifyListeners();
  }

  Future<int?> _probeDurationMs(String path) async {
    return await extractDuration(path);
  }

  // ── 오디오 파형 추출 ──────────────────────────────────────────────────────

  /// 영상에서 오디오 파형을 뽑는다.
  ///
  /// 호출한 쪽이 await 하지 않는다. 영상을 빠르게 두 번 고르면 ffmpeg 작업이
  /// 겹치는데, 전에는 둘 다 `aw_tmp_audio.pcm` 한 경로에 쓰고 늦게 끝난 쪽이
  /// _waveformData를 덮었다. 그래서 두 번째 영상 밑에 첫 번째 영상의 파형이
  /// 걸리는 일이 있었다.
  ///
  /// 요청마다 번호와 파일 이름을 따로 준다. 자기보다 새 요청이 생겼으면
  /// 결과를 버리고, 자기가 만든 임시 파일은 어떤 경로로 끝나든 자기가 지운다.
  Future<void> _extractWaveform(String videoPath) async {
    final requestId = ++_waveformRequestId;

    _waveformLoading = true;
    _waveformData = null;
    notifyListeners();

    AppLogger.i('[Captioning][Waveform] 파형 추출 시작 path=$videoPath');

    final tmpDir = await getTemporaryDirectory();
    final pcmOut = '${tmpDir.path}/aw_tmp_audio_$requestId.pcm';
    final outFile = File(pcmOut);
    _tempPcmPath = pcmOut;

    try {
      await _deleteQuietly(outFile);

      final session = await FFmpegKit.executeWithArguments([
        '-y',
        '-i',
        videoPath,
        '-vn',
        '-ac',
        '1',
        '-ar',
        '8000',
        '-f',
        's16le',
        '-t',
        '180',
        pcmOut,
      ]);
      final rc = await session.getReturnCode();

      if (requestId != _waveformRequestId) return;

      if (!ReturnCode.isSuccess(rc) || !await outFile.exists()) {
        final logs = await session.getAllLogsAsString();
        AppLogger.w('[Captioning][Waveform] ffmpeg PCM 추출 실패 logs=$logs');
        _waveformLoading = false;
        notifyListeners();
        return;
      }

      AppLogger.d('[Captioning][Waveform] PCM 추출 성공 out=$pcmOut');

      final bytes = await outFile.readAsBytes();
      final data = _computeWaveformFromPcm(bytes);

      if (requestId != _waveformRequestId) return;

      AppLogger.i('[Captioning][Waveform] 파형 계산 완료 samples=${data.length}');

      _waveformData = data;
      _waveformLoading = false;
      notifyListeners();
    } catch (e) {
      AppLogger.e('[Captioning][Waveform] 파형 추출 예외', error: e);
      if (requestId != _waveformRequestId) return;
      _waveformLoading = false;
      notifyListeners();
    } finally {
      // 180초 분량이면 3MB쯤 된다. 다 읽었으면 들고 있을 이유가 없다.
      await _deleteQuietly(outFile);
      if (_tempPcmPath == pcmOut) _tempPcmPath = null;
    }
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (e) {
      AppLogger.w('[Captioning][Waveform] 임시 PCM 파일 삭제 실패', error: e);
    }
  }

  static List<double> _computeWaveformFromPcm(Uint8List bytes) {
    final sampleCount = bytes.length ~/ 2;
    if (sampleCount == 0) return [];

    final byteData = ByteData.sublistView(bytes);
    const int samplesPerPoint = 160;
    final int pointCount = (sampleCount / samplesPerPoint).ceil();
    final result = <double>[];

    for (int i = 0; i < pointCount; i++) {
      final start = i * samplesPerPoint;
      if (start >= sampleCount) break;
      final end = (start + samplesPerPoint).clamp(0, sampleCount);

      double sumSq = 0;
      for (int j = start; j < end; j++) {
        final sample = byteData.getInt16(j * 2, Endian.little).toDouble();
        sumSq += sample * sample;
      }
      final rms = (end > start) ? (sumSq / (end - start)) : 0.0;
      result.add(rms);
    }

    if (result.isEmpty) return [];

    final maxVal = result.reduce((a, b) => a > b ? a : b);
    if (maxVal <= 0) return result.map((_) => 0.0).toList();
    return result.map((v) => (v / maxVal).clamp(0.0, 1.0)).toList();
  }

  Future<void> _cleanupTempPcm() async {
    final path = _tempPcmPath;
    if (path == null) return;
    _tempPcmPath = null;
    await _deleteQuietly(File(path));
  }

  // Mixin 초기화 헬퍼
  (PickVideoUseCase, ExtractThumbnailUseCase, ExtractDurationUseCase)
      initFileDeps() {
    return (
      PickVideoUseCase(
          files: VideoPickerFiles(), gallery: VideoPickerGallery()),
      ExtractThumbnailUseCase(VideoMetaServiceImpl()),
      ExtractDurationUseCase(VideoMetaServiceImpl()),
    );
  }
}
