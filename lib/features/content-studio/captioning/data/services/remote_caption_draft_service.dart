import 'package:parrokit/features/content-studio/captioning/domain/validators/clip_validator.dart';
import 'package:parrokit/features/content-studio/captioning/data/constants/edit_strings.dart';
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

  /// 길이 한도는 ClipValidator 한 곳에서 정한다(5차 434).
  static const int maxCaptionDurationMs = ClipValidator.maxDurationMs;

  final AsrEngine engine;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;
  final Uuid _uuid = const Uuid();

  @override
  Future<DraftResult> generate({
    required String filePath,
    required int durationMs,
    void Function(int current, int total, String message)? onProgress,
  }) async {
    if (durationMs <= 0 || durationMs > maxCaptionDurationMs) {
      throw ArgumentError(ClipValidator.tooLongMessage());
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw ArgumentError('로그인이 필요해요.');
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
      onProgress?.call(1, 1, EditStrings.sttRunningLabel);
      final callable = _functions.httpsCallable(
        'generateCaptions',
        options: HttpsCallableOptions(timeout: const Duration(minutes: 9)),
      );
      final result = await callable.call<Map<String, dynamic>>({
        'storagePath': storagePath,
        'engine': 'whisper',
        'durationMs': durationMs,
        // 패롯은 서버가 자막을 만든 뒤 깎는다. 모자라면 가진 만큼만 깎는다.
        'serverCharge': true,
        'requestId': requestId,
      });

      final segments = _parseSegments(result.data['segments']);
      final coinCost = (result.data['chargedParrots'] as num?)?.toInt() ?? 0;
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
      // 아래 네 가지는 모두 서버 쪽 사정이다. 사용자가 고칠 수 없으니
      // 무엇을 확인하라고 시키지 않는다(5차 428).
      'resource-exhausted' => EditStrings.sttServerProblemMessage,
      'unauthenticated' => '로그인이 필요해요.',
      'permission-denied' => EditStrings.sttServerProblemMessage,
      'invalid-argument' => EditStrings.sttBadInputMessage,
      'failed-precondition' => EditStrings.sttServerProblemMessage,
      _ => EditStrings.sttFailedMessage,
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
}
