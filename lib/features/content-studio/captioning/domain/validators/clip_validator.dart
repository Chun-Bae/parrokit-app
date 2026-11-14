// ============================================================================
// lib/features/content-studio/captioning/domain/validators/clip_validator.dart
// ============================================================================
//
// [역할]
// 클립 폼 유효성 검증 로직. UI 독립적인 순수 비즈니스 로직.
//
// [레이어]
// Domain Layer
// ============================================================================

import '../models/clip_form_data.dart';

class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  const ValidationResult.valid()
      : isValid = true,
        errorMessage = null;

  const ValidationResult.invalid(this.errorMessage) : isValid = false;
}

class ClipValidator {
  static const int maxDurationMs = 5 * 60 * 1000;
  static final RegExp timecodePattern = RegExp(r'^\d{2}:\d{2}\.\d{3}$');

  /// 영상을 고르기 전에도 알 수 있는 것만 본다. 저장 버튼을 끌 때 쓴다.
  ///
  /// 막는 까닭은 [validateForm]이 쓰는 말과 똑같이 둔다. 버튼 아래 안내와
  /// 눌렀을 때 토스트가 다른 말이면 더 헷갈린다(5차).
  static String? blockedReason({
    required String filePath,
    required String folder,
    required String title,
  }) {
    if (filePath.trim().isEmpty) return noFileMessage;
    if (folder.trim().isEmpty) return noFolderMessage;
    if (title.trim().isEmpty) return noTitleMessage;
    return null;
  }

  static const noFileMessage = '영상 파일을 먼저 선택해 주세요.';
  static const noFolderMessage = '폴더를 골라 주세요.';
  static const noTitleMessage = '클립 제목을 적어 주세요.';

  ValidationResult validateForm(ClipFormData form) {
    if (form.filePath == null || form.filePath!.isEmpty) {
      return const ValidationResult.invalid(noFileMessage);
    }

    if (form.collectionName == null || form.collectionName!.trim().isEmpty) {
      return const ValidationResult.invalid(noFolderMessage);
    }

    if (form.clipTitle.trim().isEmpty) {
      return const ValidationResult.invalid(noTitleMessage);
    }

    if (form.durationMs == null || form.durationMs! <= 0) {
      return const ValidationResult.invalid('영상 길이를 읽지 못했어요. 영상을 다시 골라 주세요.');
    }
    if (form.durationMs! > maxDurationMs) {
      return const ValidationResult.invalid('5분 이하 영상만 넣을 수 있어요.');
    }

    final segmentResult = validateSegments(form.segments, form.durationMs!);
    if (!segmentResult.isValid) {
      return segmentResult;
    }

    return const ValidationResult.valid();
  }

  // 화면은 '구간', 'A·B', '원문·해석·발음'이라고 부르는데 오류 문구만 '세그먼트',
  // '필드', '시작·종료'라서 무엇을 고칠지 알기 어려웠다(5차). 화면 말로 맞춘다.
  ValidationResult validateSegments(
      List<SegmentInput> segments, int durationMs) {
    if (segments.isEmpty) {
      return const ValidationResult.invalid('구간을 하나 이상 만들어 주세요.');
    }

    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final idx = i + 1;

      if (!seg.isComplete) {
        return ValidationResult.invalid('구간 $idx: 원문·해석·발음을 모두 적어 주세요.');
      }

      if (!timecodePattern.hasMatch(seg.start)) {
        return ValidationResult.invalid('구간 $idx: A 시각을 다시 확인해 주세요.');
      }
      if (!timecodePattern.hasMatch(seg.end)) {
        return ValidationResult.invalid('구간 $idx: B 시각을 다시 확인해 주세요.');
      }

      final startMs = _parseTimecode(seg.start);
      final endMs = _parseTimecode(seg.end);

      if (endMs <= startMs) {
        return ValidationResult.invalid('구간 $idx: B가 A보다 뒤여야 해요.');
      }
      if (startMs < 0 || endMs > durationMs) {
        return ValidationResult.invalid('구간 $idx: 영상 길이를 넘어요.');
      }
    }

    final sorted = List<SegmentInput>.from(segments)
      ..sort(
          (a, b) => _parseTimecode(a.start).compareTo(_parseTimecode(b.start)));

    for (int i = 1; i < sorted.length; i++) {
      final prevEnd = _parseTimecode(sorted[i - 1].end);
      final currStart = _parseTimecode(sorted[i].start);
      if (currStart < prevEnd) {
        return ValidationResult.invalid('겹치는 구간이 있어요: $i번, ${i + 1}번');
      }
    }

    return const ValidationResult.valid();
  }

  int _parseTimecode(String tc) {
    final parts = tc.split(':');
    if (parts.length != 2) return 0;
    final min = int.tryParse(parts[0]) ?? 0;
    final secParts = parts[1].split('.');
    if (secParts.length != 2) return min * 60 * 1000;
    final sec = int.tryParse(secParts[0]) ?? 0;
    final ms = int.tryParse(secParts[1]) ?? 0;
    return (min * 60 + sec) * 1000 + ms;
  }
}
