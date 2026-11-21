// ============================================================================
// lib/features/content-studio/captioning/domain/models/clip_form_data.dart
// ============================================================================
//
// [역할]
// 클립 에디터 폼 데이터. UI 독립적인 순수 데이터 클래스.
//
// [레이어]
// Domain Layer
// ============================================================================

/// 세그먼트 순수 데이터 (UI 독립적).
class SegmentInput {
  final String start;
  final String end;
  final String original;
  final String pron;
  final String ko;

  const SegmentInput({
    this.start = '',
    this.end = '',
    this.original = '',
    this.pron = '',
    this.ko = '',
  });

  SegmentInput copyWith({
    String? start,
    String? end,
    String? original,
    String? pron,
    String? ko,
  }) {
    return SegmentInput(
      start: start ?? this.start,
      end: end ?? this.end,
      original: original ?? this.original,
      pron: pron ?? this.pron,
      ko: ko ?? this.ko,
    );
  }

  bool get isEmpty =>
      start.isEmpty &&
      end.isEmpty &&
      original.isEmpty &&
      pron.isEmpty &&
      ko.isEmpty;

  bool get isComplete =>
      start.isNotEmpty &&
      end.isNotEmpty &&
      original.isNotEmpty &&
      pron.isNotEmpty &&
      ko.isNotEmpty;
}

/// 클립 에디터 폼 전체 데이터.
class ClipFormData {
  final String? collectionName;
  final String clipTitle;
  final int? durationMs;
  final List<SegmentInput> segments;
  final List<String> tags;
  final String? filePath;

  const ClipFormData({
    this.collectionName,
    this.clipTitle = '',
    this.durationMs,
    this.segments = const [],
    this.tags = const [],
    this.filePath,
  });

  ClipFormData copyWith({
    Object? collectionName = _sentinel,
    String? clipTitle,
    int? durationMs,
    List<SegmentInput>? segments,
    List<String>? tags,
    String? filePath,
  }) {
    return ClipFormData(
      collectionName: collectionName == _sentinel
          ? this.collectionName
          : collectionName as String?,
      clipTitle: clipTitle ?? this.clipTitle,
      durationMs: durationMs ?? this.durationMs,
      segments: segments ?? this.segments,
      tags: tags ?? this.tags,
      filePath: filePath ?? this.filePath,
    );
  }
}

const _sentinel = Object();

/// 입력칸에 담긴 것을 한 줄로 적는다. 바뀌었는지 견주는 데만 쓴다(5차 523).
///
/// 편집으로 연 클립은 구경만 하고 나가도 '지금 나가면 적은 내용이 모두
/// 사라져요'가 떴다. 불러온 직후의 이 줄과 나갈 때의 줄을 견줘서, 같으면
/// 묻지 않는다.
String clipFormFingerprint(ClipFormData data) => [
      data.collectionName ?? '',
      data.clipTitle,
      data.durationMs?.toString() ?? '',
      data.filePath ?? '',
      data.tags.join('\u0001'),
      for (final seg in data.segments)
        [seg.start, seg.end, seg.original, seg.pron, seg.ko].join('\u0002'),
    ].join('\u0003');
