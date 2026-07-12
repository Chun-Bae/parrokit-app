/// 지원하는 Veo 해상도. 4K는 원가가 크게 뛰고 일부 모델은 지원도 안 해
/// 채택하지 않는다.
const String veo31Resolution720p = '720p';
const String veo31Resolution1080p = '1080p';

/// 1080p(4K도 마찬가지)는 8초 영상만 지원한다.
bool veo31ResolutionRequiresEightSeconds(String resolution) =>
    resolution == veo31Resolution1080p;

class VideoGenerationModel {
  const VideoGenerationModel({
    required this.id,
    required this.name,
    required this.description,
    required this.costPerSecond720p,
    required this.costPerSecond1080p,
  });

  final String id;
  final String name;
  final String description;

  /// 720p로 1초 분량을 생성할 때 소모되는 패롯.
  final int costPerSecond720p;

  /// 1080p로 1초 분량을 생성할 때 소모되는 패롯.
  final int costPerSecond1080p;

  int costPerSecond(String resolution) => resolution == veo31Resolution1080p
      ? costPerSecond1080p
      : costPerSecond720p;
}

class VideoGenerationRecord {
  const VideoGenerationRecord({
    required this.uid,
    required this.generationId,
    required this.prompt,
    required this.modelId,
    required this.aspectRatio,
    required this.durationSeconds,
    required this.status,
    required this.videoUrl,
    required this.createdAt,
    required this.updatedAt,
    required this.expiresAt,
    required this.ttlHours,
  });

  final String uid;
  final String generationId;
  final String prompt;
  final String modelId;
  final String aspectRatio;
  final int durationSeconds;
  final String status;
  final String? videoUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? expiresAt;
  final int? ttlHours;

  bool get isOperatorAccount => isOperatorUid(uid);
  bool get hasExpiryCountdown => !isOperatorAccount && expiresAt != null;

  String get retentionLabel {
    if (isOperatorAccount) {
      return '계속 보관';
    }

    final expiry = expiresAt;
    if (expiry == null) {
      return '보관 정보 없음';
    }

    final remaining = expiry.difference(DateTime.now());
    if (remaining.isNegative) {
      return '남은 시간 0분';
    }

    return '남은 시간 ${_formatRemainingDuration(remaining)}';
  }

  factory VideoGenerationRecord.fromMap(Map<String, dynamic> map) {
    final storagePath =
        (map['storagePath'] ?? map['storage_path'] ?? '').toString();
    final uid = _resolveUid(
      (map['uid'] ?? '').toString(),
      storagePath,
    );

    return VideoGenerationRecord(
      uid: uid,
      generationId: (map['generationId'] ?? '').toString(),
      prompt: (map['prompt'] ?? '').toString(),
      modelId: (map['modelId'] ?? '').toString(),
      aspectRatio: (map['aspectRatio'] ?? '').toString(),
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      status: (map['status'] ?? '').toString(),
      videoUrl:
          map['videoUrl'] is String && (map['videoUrl'] as String).isNotEmpty
              ? map['videoUrl'] as String
              : null,
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
      expiresAt: _parseDateTime(map['expiresAt']),
      ttlHours: (map['ttlHours'] as num?)?.toInt(),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static String _resolveUid(String uid, String storagePath) {
    if (uid.isNotEmpty) {
      return uid;
    }

    final match = RegExp(r'^users/([^/]+)/content-studio/videos/').firstMatch(
      storagePath,
    );
    if (match != null && match.group(1) != null) {
      return Uri.decodeComponent(match.group(1)!);
    }

    return '';
  }

  static String _formatRemainingDuration(Duration duration) {
    final totalMinutes = duration.inMinutes;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      if (minutes > 0) {
        return '$hours시간 $minutes분';
      }

      return '$hours시간';
    }

    if (minutes > 0) {
      return '$minutes분';
    }

    return '$seconds초';
  }
}

const Set<String> operatorUids = {
  'dDsWhAQWQxfCWI4xHIayCkjLD662',
  'naver:iDj5CROn8PODq_1sTN1Yjt2tvaaKiJUppIfKR5-IXmA',
};

bool isOperatorUid(String? uid) {
  return uid != null && operatorUids.contains(uid);
}

const String veo31LiteModelId = 'veo-3.1-lite-generate-preview';
const String veo31FastModelId = 'veo-3.1-fast-generate-preview';
const String veo31StandardModelId = 'veo-3.1-generate-preview';

const List<VideoGenerationModel> veo31Models = [
  VideoGenerationModel(
    id: veo31LiteModelId,
    name: 'Veo 3.1 Lite',
    description: '가장 빠른 생성, 낮은 비용',
    costPerSecond720p: 11,
    costPerSecond1080p: 17,
  ),
  VideoGenerationModel(
    id: veo31FastModelId,
    name: 'Veo 3.1 Fast',
    description: '속도와 품질의 균형',
    costPerSecond720p: 21,
    costPerSecond1080p: 26,
  ),
  VideoGenerationModel(
    id: veo31StandardModelId,
    name: 'Veo 3.1 Standard',
    description: '가장 높은 품질, 세밀한 연출',
    costPerSecond720p: 86,
    costPerSecond1080p: 86,
  ),
];

String normalizeVeo31ModelId(String? modelId) {
  switch (modelId) {
    case 'veo3.1-lite':
    case veo31LiteModelId:
      return veo31LiteModelId;
    case 'veo3.1-fast':
    case veo31FastModelId:
      return veo31FastModelId;
    case 'veo3.1-standard':
    case 'veo3.1-full':
    case veo31StandardModelId:
      return veo31StandardModelId;
    default:
      return veo31LiteModelId;
  }
}

VideoGenerationModel veo31ModelById(String? modelId) {
  final normalizedId = normalizeVeo31ModelId(modelId);
  return veo31Models.firstWhere(
    (model) => model.id == normalizedId,
    orElse: () => veo31Models.first,
  );
}

/// 모델 등급, 해상도, 길이(초)에 따른 예상 소모 패롯.
int veo31GenerationCost({
  required String? modelId,
  required int durationSeconds,
  String resolution = veo31Resolution720p,
}) {
  if (durationSeconds <= 0) return 0;
  return veo31ModelById(modelId).costPerSecond(resolution) * durationSeconds;
}
