// 클립에 자막을 구워 새 영상 파일을 만든다(5차, 사용자 요청).
//
// 계산(자막 글자·명령 조립)은 domain/subtitle_burn.dart에 있고, 여기서는
// 파일을 놓고 ffmpeg를 돌리는 일만 한다.

import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:parrokit/data/local/app_database.dart';
import 'package:parrokit/features/collection/clip/export/domain/subtitle_burn.dart';

/// 구운 결과. 실패하면 [path]가 null이고 [message]에 까닭이 있다.
class SubtitleBurnResult {
  const SubtitleBurnResult({this.path, this.message, this.canceled = false});

  final String? path;
  final String? message;
  final bool canceled;

  bool get isSuccess => path != null;
}

class SubtitleBurnService {
  SubtitleBurnService();

  /// 지금 돌고 있는 작업. 취소할 때 쓴다.
  FFmpegSession? _session;

  /// 글꼴은 앱이 들고 있는 것을 쓴다. 기기 글꼴에 맡기면 한글이 깨진다.
  static const _fontAsset =
      'assets/fonts/IBMPlexSansKR/IBMPlexSansKR-SemiBold.ttf';
  static const _fontFileName = 'IBMPlexSansKR-SemiBold.ttf';

  /// 자막을 구운 새 영상을 만든다. [onProgress]는 0~1.
  Future<SubtitleBurnResult> burn({
    required String videoPath,
    required List<Segment> segments,
    required String clipTitle,
    required Duration videoLength,
    SubtitleBurnOptions options = const SubtitleBurnOptions(),
    void Function(double progress)? onProgress,
  }) async {
    final srt = buildSrt(segments, options);
    if (srt.isEmpty) {
      return const SubtitleBurnResult(message: '넣을 자막이 없어요.');
    }
    if (!await File(videoPath).exists()) {
      return const SubtitleBurnResult(message: '영상 파일을 찾을 수 없어요.');
    }

    final workDir = Directory(
        '${(await getTemporaryDirectory()).path}/subtitle-burn');
    if (!await workDir.exists()) await workDir.create(recursive: true);

    final subtitlePath = '${workDir.path}/subtitle.srt';
    await File(subtitlePath).writeAsString(srt);
    final fontsDir = await _ensureFontDir(workDir.path);
    final outputPath = '${workDir.path}/${exportFileName(clipTitle)}';

    final arguments = burnArguments(
      inputPath: videoPath,
      subtitlePath: subtitlePath,
      fontsDir: fontsDir,
      outputPath: outputPath,
    );

    final totalMs = videoLength.inMilliseconds;
    final completer = Completer<SubtitleBurnResult>();
    _session = await FFmpegKit.executeWithArgumentsAsync(
      arguments,
      (session) async {
        _session = null;
        final code = await session.getReturnCode();
        if (ReturnCode.isSuccess(code)) {
          onProgress?.call(1);
          completer.complete(SubtitleBurnResult(path: outputPath));
          return;
        }
        if (ReturnCode.isCancel(code)) {
          completer.complete(const SubtitleBurnResult(canceled: true));
          return;
        }
        final logs = await session.getAllLogsAsString();
        AppLogger.w('[SubtitleBurn] 실패: ${logs?.split('\n').last}');
        completer.complete(
            const SubtitleBurnResult(message: '자막을 넣지 못했어요. 다시 시도해 주세요.'));
      },
      null,
      (statistics) {
        if (totalMs <= 0 || onProgress == null) return;
        final done = statistics.getTime();
        onProgress((done / totalMs).clamp(0.0, 0.99));
      },
    );
    return completer.future;
  }

  /// 돌고 있는 작업을 멈춘다. 멈추면 burn이 canceled로 끝난다.
  Future<void> cancel() async {
    final session = _session;
    if (session == null) return;
    await FFmpegKit.cancel(session.getSessionId());
  }

  /// 앱 안의 글꼴을 파일로 꺼내 둔다. ffmpeg는 자산 번들을 읽지 못한다.
  Future<String> _ensureFontDir(String workDirPath) async {
    final dir = Directory('$workDirPath/fonts');
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File('${dir.path}/$_fontFileName');
    if (!await file.exists()) {
      final bytes = await rootBundle.load(_fontAsset);
      await file.writeAsBytes(bytes.buffer.asUint8List());
    }
    return dir.path;
  }

  /// 내보내고 남은 파일을 지운다. 영상이라 꽤 크다.
  static Future<void> clearWorkDir() async {
    try {
      final dir = Directory(
          '${(await getTemporaryDirectory()).path}/subtitle-burn');
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (error) {
      AppLogger.w('[SubtitleBurn] 임시 파일을 지우지 못했어요: $error');
    }
  }

  /// FFmpegKit 로그를 앱 로그로 넘긴다(진단용). 켜 두면 로그가 많다.
  static void enableLogs() {
    FFmpegKitConfig.enableLogCallback(
        (log) => AppLogger.d('[SubtitleBurn] ${log.getMessage()}'));
  }
}
