// ============================================================================
// lib/features/_content/clip_editor/data/adapters/openai_asr_base.dart
// ============================================================================
//
// [역할]
// OpenAI 계열 ASR 어댑터의 공통 베이스.
// 파일 변환(WAV), multipart 빌드, 응답 파싱 등 공통 로직을 제공합니다.
// 모델별 차이(model명, response_format, 추가 필드)는 서브클래스가 오버라이드.
//
// [레이어]
// Data Layer > Adapters
// ============================================================================

// dart 내장
import 'dart:convert';
import 'dart:io';

// package
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';

// relative
import '../constants/openai_constants.dart';
import '../ports/asr_port.dart';
import 'openai_api_exception.dart';

/// OpenAI ASR 어댑터 공통 베이스.
abstract class OpenAIAsrBase implements ASRPort {
  final String apiKey;

  OpenAIAsrBase({required this.apiKey});

  // ─────────────────────────────────────────────────────────────────
  // 서브클래스가 정의해야 하는 항목
  // ─────────────────────────────────────────────────────────────────

  /// 사용할 OpenAI 모델 이름.
  String get model;

  /// API 응답 포맷 (예: 'json', 'verbose_json', 'diarized_json').
  String get responseFormat;

  /// 모델별 추가 필드를 multipart 요청에 주입할 훅.
  void configureExtraFields(http.MultipartRequest req) {}

  // ─────────────────────────────────────────────────────────────────
  // 파일 변환
  // ─────────────────────────────────────────────────────────────────

  /// 동영상/오디오 파일을 WAV로 변환합니다.
  Future<String> _ensureWav(String path) async {
    final normalized = path.startsWith('file://') ? path.substring(7) : path;
    final ext = p.extension(normalized).toLowerCase();

    if (ext == '.wav') return normalized;

    try {
      final tmpDir = await getTemporaryDirectory();
      final wavPath =
          '${tmpDir.path}/stt_${DateTime.now().millisecondsSinceEpoch}.wav';

      final cmd =
          '-hide_banner -loglevel info -y -i "$normalized" -map 0:a:0 -map_metadata -1 -af "volume=2" -ac 1 -ar 16000 -sample_fmt s16 -c:a pcm_s16le "$wavPath"';

      final session = await FFmpegKit.execute(cmd);
      final rc = await session.getReturnCode();

      if (rc != null && rc.isValueSuccess() && await File(wavPath).exists()) {
        return wavPath;
      }

      final logs = await session.getAllLogsAsString();
      AppLogger.e('FFmpeg 변환 실패. rc=${rc?.getValue()}\n$logs');
      return normalized;
    } on MissingPluginException catch (e) {
      AppLogger.w('FFmpeg 플러그인 없음. 원본 사용. $e');
      return normalized;
    } catch (e) {
      AppLogger.e('FFmpeg 예외. 원본 사용.', error: e);
      return normalized;
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // ASRPort 구현
  // ─────────────────────────────────────────────────────────────────

  @override
  Future<ASRResult> transcribe({
    String? filePath,
    Uint8List? bytes,
    String? language,
    bool withSegments = true,
    Duration? timeout,
  }) async {
    if ((filePath == null || filePath.isEmpty) &&
        (bytes == null || bytes.isEmpty)) {
      throw ArgumentError('filePath 또는 bytes 중 하나는 필수입니다.');
    }

    final cleanKey =
        apiKey.trim().replaceAll('\u201C', '').replaceAll('\u201D', '');
    if (cleanKey.isEmpty) {
      throw ArgumentError('OPENAI_API_KEY가 비어있습니다.');
    }

    final req =
        http.MultipartRequest('POST', Uri.parse(OpenAIConstants.asrEndpoint));
    req.headers['Authorization'] = 'Bearer $cleanKey';
    req.fields['model'] = model;
    req.fields['temperature'] = '0';
    req.fields['response_format'] = responseFormat;

    if (language != null && language.isNotEmpty) {
      req.fields['language'] = language;
    }

    // 서브클래스 훅
    configureExtraFields(req);

    // 파일 첨부
    if (filePath != null && filePath.isNotEmpty) {
      final uploadPath = await _ensureWav(filePath);
      final filename = p.basename(uploadPath);

      AppLogger.d('STT 업로드($model): $uploadPath');

      req.files.add(await http.MultipartFile.fromPath(
        'file',
        uploadPath,
        filename: filename,
        contentType: _contentTypeFor(uploadPath),
      ));
    } else {
      final filename = 'audio_${DateTime.now().millisecondsSinceEpoch}.wav';
      req.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes!,
        filename: filename,
        contentType: MediaType('audio', 'wav'),
      ));
    }

    final streamed =
        await req.send().timeout(timeout ?? const Duration(seconds: 1000));
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode != 200) {
      throw OpenAIApiException.fromResponse(
        statusCode: res.statusCode,
        body: res.body,
        fallbackAction: '음성 인식',
      );
    }

    final map = jsonDecode(res.body) as Map<String, dynamic>;
    AppLogger.d('ASR 응답: ${res.body}');

    return _parseResult(map, withSegments);
  }

  // ─────────────────────────────────────────────────────────────────
  // 응답 파싱
  // ─────────────────────────────────────────────────────────────────

  ASRResult _parseResult(Map<String, dynamic> map, bool withSegments) {
    final text = (map['text'] as String?)?.trim() ?? '';

    if (!withSegments) {
      return ASRResult(text: text);
    }

    final segments = <ASRSegment>[];
    final segSrc = map['segments'];

    if (segSrc is List) {
      for (final e in segSrc) {
        if (e is Map) {
          final startSec = _parseDouble(e['start']);
          final endSec = _parseDouble(e['end']);
          final segText = (e['text'] as String?)?.trim() ?? '';

          segments.add(ASRSegment(
            startMs: (startSec * 1000).round(),
            endMs: (endSec * 1000).round(),
            text: segText,
          ));
        }
      }
    }

    return ASRResult(text: text, segments: segments);
  }

  /// 파일 확장자에 맞는 MIME type을 반환합니다.
  MediaType _contentTypeFor(String path) {
    final ext = p.extension(path).toLowerCase();
    return switch (ext) {
      '.mp3' => MediaType('audio', 'mpeg'),
      '.wav' => MediaType('audio', 'wav'),
      '.m4a' || '.aac' => MediaType('audio', 'mp4'),
      '.flac' => MediaType('audio', 'flac'),
      '.ogg' || '.opus' => MediaType('audio', 'ogg'),
      '.mp4' => MediaType('video', 'mp4'),
      '.webm' => MediaType('video', 'webm'),
      _ => MediaType('application', 'octet-stream'),
    };
  }

  double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0.0;
  }
}
