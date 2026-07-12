// ============================================================================
// lib/features/content-studio/captioning/data/services/remote_caption_draft_service.dart
// ============================================================================
//
// [역할]
// 자동 자막 생성을 Firebase Storage + Cloud Functions 경유로 요청합니다.
//
// [레이어]
// Data Layer > Services
// ============================================================================

import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/clip_form_data.dart';
import '../adapters/asr_engine.dart';
import '../ports/caption_draft_port.dart';

/// 서버 기반 자동 자막 생성 실패.
class RemoteCaptionDraftException implements Exception {
  const RemoteCaptionDraftException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Firebase Functions 기반 자동 자막 초안 생성 서비스.
class RemoteCaptionDraftService implements CaptionDraftGenerator {
  RemoteCaptionDraftService({
    required this.engine,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  static const int maxCaptionDurationMs = 5 * 60 * 1000;

  final AsrEngine engine;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;
  final Uuid _uuid = const Uuid();

  @override
  Future<DraftResult> generate({
    required String filePath,
    required int durationMs,
    String language = 'ja',
    void Function(int current, int total, String message)? onProgress,
  }) async {
    if (durationMs <= 0 || durationMs > maxCaptionDurationMs) {
      throw ArgumentError('자동 자막은 5분 이하 파일만 처리할 수 있습니다.');
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw ArgumentError('로그인이 필요합니다.');
    }

    final normalizedPath =
        filePath.startsWith('file://') ? filePath.substring(7) : filePath;
    final uploadPath = await _ensureWav(normalizedPath);
    final file = File(uploadPath);
    final shouldDeleteUploadFile = uploadPath != normalizedPath;

    if (!await file.exists()) {
      throw ArgumentError('자동 자막 파일을 찾을 수 없습니다.');
    }

    final requestId = _uuid.v4();
    final extension = p.extension(uploadPath).toLowerCase();
    final storagePath =
        'caption-inputs/${user.uid}/$requestId/source${extension.isEmpty ? '.bin' : extension}';
    final ref = _storage.ref(storagePath);
    final contentType = lookupMimeType(uploadPath) ?? 'audio/wav';

    try {
      onProgress?.call(0, 1, '파일 업로드 중');
      await ref.putFile(file, SettableMetadata(contentType: contentType));
      onProgress?.call(1, 1, '자동 자막 생성 중');
      final callable = _functions.httpsCallable(
        'generateCaptions',
        options: HttpsCallableOptions(timeout: const Duration(minutes: 9)),
      );
      final result = await callable.call<Map<String, dynamic>>({
        'storagePath': storagePath,
        'engine': engine == AsrEngine.diarize ? 'diarize' : 'whisper',
        'language': language,
        'durationMs': durationMs,
      });

      final segments = _parseSegments(result.data['segments']);
      final coinCost = _calculateCoinCost(durationMs);
      return DraftResult(segments: segments, coinCost: coinCost);
    } on FirebaseFunctionsException catch (e) {
      throw RemoteCaptionDraftException(_messageForFunctionsError(e));
    } finally {
      if (shouldDeleteUploadFile) {
        await file.delete().catchError((_) => file);
      }
    }
  }

  Future<String> _ensureWav(String path) async {
    final extension = p.extension(path).toLowerCase();
    if (extension == '.wav') return path;

    final tempDirectory = await getTemporaryDirectory();
    final wavPath =
        '${tempDirectory.path}/stt_${DateTime.now().millisecondsSinceEpoch}.wav';
    final command =
        '-hide_banner -loglevel error -y -i "${path.replaceAll('"', r'\"')}" '
        '-map 0:a:0 -map_metadata -1 -af "volume=2" -ac 1 -ar 16000 '
        '-sample_fmt s16 -c:a pcm_s16le "$wavPath"';

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (returnCode != null &&
        returnCode.isValueSuccess() &&
        await File(wavPath).exists()) {
      return wavPath;
    }

    final logs = await session.getAllLogsAsString();
    AppLogger.e(
      '[Captioning][RemoteDraft] WAV 변환 실패 rc=${returnCode?.getValue()}\n$logs',
    );
    throw ArgumentError('자동 자막용 오디오 변환에 실패했습니다.');
  }

  String _messageForFunctionsError(FirebaseFunctionsException error) {
    final message = error.message?.trim();
    if (message != null &&
        message.isNotEmpty &&
        message.toUpperCase() != 'INTERNAL') {
      return message;
    }

    return switch (error.code) {
      'resource-exhausted' => 'OpenAI API 할당량이 부족합니다. 결제 상태를 확인해 주세요.',
      'unauthenticated' => '로그인이 필요합니다.',
      'permission-denied' => '자동 자막 파일 권한을 확인해 주세요.',
      'invalid-argument' => '자동 자막 요청 정보를 다시 확인해 주세요.',
      'failed-precondition' => '자동 자막 서버 설정을 확인해 주세요.',
      _ => '자동 자막 생성 중 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.',
    };
  }

  List<SegmentInput> _parseSegments(dynamic source) {
    if (source is! List) return const [];

    return source.whereType<Map>().map((item) {
      return SegmentInput(
        start: (item['start'] ?? '').toString(),
        end: (item['end'] ?? '').toString(),
        original: (item['original'] ?? '').toString(),
        pron: (item['pron'] ?? '').toString(),
        ko: (item['ko'] ?? '').toString(),
      );
    }).toList(growable: false);
  }

  int _calculateCoinCost(int durationMs) {
    final seconds = (durationMs / 1000).ceil();
    if (seconds <= 0) return 0;
    return ((seconds + 9) ~/ 10);
  }
}
