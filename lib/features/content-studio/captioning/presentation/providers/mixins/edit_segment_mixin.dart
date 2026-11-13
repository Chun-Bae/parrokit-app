// ============================================================================
// lib/features/content-studio/captioning/presentation/providers/mixins/edit_segment_mixin.dart
// ============================================================================
//
// [역할]
// 세그먼트 관리 mixin.
//
// [레이어]
// Presentation Layer > Provider > Mixin
// ============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:parrokit/core/shared/utils/show_toast.dart';
import '../../../domain/utils/timecode_service.dart';
import '../../models/edit_state.dart';

/// 세그먼트 관리 mixin.
mixin EditSegmentMixin on ChangeNotifier {
  // 의존성 (추상 getter)
  TextEditingController get durationCtl;

  // ─────────────────────────────────────────────────────────────────
  // 상태
  // ─────────────────────────────────────────────────────────────────
  final List<SegmentFormData> segmentForms = [];
  final List<_SegmentRangeSnapshot> _segmentSnapshots = [];

  int get _maxDurationMs {
    final text = durationCtl.text.trim();
    if (text.isNotEmpty) {
      final ms = int.tryParse(text);
      if (ms != null && ms > 0) {
        return ms;
      }
    }
    return 2147483647;
  }

  // ─────────────────────────────────────────────────────────────────
  // 세그먼트 관리
  // ─────────────────────────────────────────────────────────────────

  /// 초기 세그먼트(폼) 하나를 추가 생성합니다.
  void initSegmentForms() {
    segmentForms.add(SegmentFormData.empty());
    _segmentSnapshots.add(_SegmentRangeSnapshot.empty());
  }

  /// 새로운 세그먼트 폼을 추가합니다.
  /// 이전 세그먼트의 종료 시간을 새 세그먼트의 시작 시간으로 자동 입력합니다.
  void addSegment() {
    final nf = SegmentFormData.empty();
    if (segmentForms.isNotEmpty) {
      nf.startCtl.text = segmentForms.last.endCtl.text;
    }
    segmentForms.add(nf);
    _segmentSnapshots.add(_SegmentRangeSnapshot.fromForm(nf));
    notifyListeners();
  }

  /// 특정 인덱스의 세그먼트를 제거합니다.
  /// (최소 1개는 유지해야 합니다)
  void removeSegment(int index) {
    if (segmentForms.length <= 1) {
      showToast('구간은 하나 이상 있어야 해요.');
      return;
    }
    final f = segmentForms.removeAt(index);
    f.dispose();
    if (index < _segmentSnapshots.length) {
      _segmentSnapshots.removeAt(index);
    }
    notifyListeners();
  }

  /// 세그먼트 폼의 개수를 [count]개로 맞춥니다 (추가/삭제).
  /// 자동 생성(STT 등) 시 사용됩니다.
  void ensureSegmentFormsLength(int count) {
    if (segmentForms.length < count) {
      while (segmentForms.length < count) {
        final nf = SegmentFormData.empty();
        if (segmentForms.isNotEmpty) {
          nf.startCtl.text = segmentForms.last.endCtl.text;
        }
        segmentForms.add(nf);
        _segmentSnapshots.add(_SegmentRangeSnapshot.fromForm(nf));
      }
    } else if (segmentForms.length > count) {
      while (segmentForms.length > count) {
        final removed = segmentForms.removeLast();
        removed.dispose();
        if (_segmentSnapshots.isNotEmpty) {
          _segmentSnapshots.removeLast();
        }
      }
    }
    notifyListeners();
  }

  /// 특정 인덱스의 세그먼트 값을 설정합니다. (STT 결과 반영 등)
  void setSegmentAt(
    int index, {
    required String start,
    required String end,
    required String original,
    required String pron,
    required String ko,
  }) {
    final f = segmentForms[index];
    f.startCtl.text = start;
    f.endCtl.text = end;
    f.originalCtl.text = original;
    f.pronCtl.text = pron;
    f.koCtl.text = ko;
    _syncSnapshotAt(index);
    notifyListeners();
  }

  /// 특정 인덱스의 시작/종료 구간을 밀리초 기준으로 갱신합니다.
  void updateSegmentRange(
    int index, {
    required int startMs,
    required int endMs,
  }) {
    if (index < 0 || index >= segmentForms.length) return;

    final tc = TimecodeService();
    final startText = tc.msToMMSSmmm(startMs);
    final endText = tc.msToMMSSmmm(endMs);
    final f = segmentForms[index];
    f.startCtl.value = TextEditingValue(
      text: startText,
      selection: TextSelection.collapsed(offset: startText.length),
    );
    f.endCtl.value = TextEditingValue(
      text: endText,
      selection: TextSelection.collapsed(offset: endText.length),
    );
    notifyListeners();
  }

  /// 시작 경계를 드래그할 때, 현재 구간만 이동하며 이전 구간을 침범하지 않도록 제한한다.
  void adjustSegmentStartConstrained(
    int index,
    int deltaMs,
  ) {
    if (index < 0 || index >= segmentForms.length || deltaMs == 0) return;

    final form = segmentForms[index];
    final startMs = _parseMs(form.startCtl.text);
    final endMs = _parseMs(form.endCtl.text);
    if (startMs == null || endMs == null) return;

    var newStartMs = startMs + deltaMs;
    const gapMs = 50;
    var lowerBound = 0;

    if (index > 0) {
      final prevEndMs = _parseMs(segmentForms[index - 1].endCtl.text);
      if (prevEndMs != null) {
        lowerBound = prevEndMs + gapMs;
      }
    }

    if (newStartMs < lowerBound) {
      newStartMs = lowerBound;
    }
    if (newStartMs > endMs - gapMs) {
      newStartMs = endMs - gapMs;
    }

    _writeSegmentRange(index, newStartMs, endMs);
    notifyListeners();
  }

  /// 끝 경계를 드래그할 때, 현재 구간만 이동하며 이후 구간을 침범하지 않도록 제한한다.
  void adjustSegmentEndConstrained(
    int index,
    int deltaMs,
  ) {
    if (index < 0 || index >= segmentForms.length || deltaMs == 0) return;

    final form = segmentForms[index];
    final startMs = _parseMs(form.startCtl.text);
    final endMs = _parseMs(form.endCtl.text);
    if (startMs == null || endMs == null) return;

    var newEndMs = endMs + deltaMs;
    const gapMs = 50;
    var upperBound = _maxDurationMs;

    if (index < segmentForms.length - 1) {
      final nextStartMs = _parseMs(segmentForms[index + 1].startCtl.text);
      if (nextStartMs != null) {
        upperBound = nextStartMs - gapMs;
      }
    }

    if (newEndMs > upperBound) {
      newEndMs = upperBound;
    }
    if (newEndMs < startMs + gapMs) {
      newEndMs = startMs + gapMs;
    }

    _writeSegmentRange(index, startMs, newEndMs);
    notifyListeners();
  }

  /// 편집 중인 특정 세그먼트를 검증하고, 겹치면 자동 보정합니다.
  bool validateSegmentAt(int index) {
    if (index < 0 || index >= segmentForms.length) return true;

    final form = segmentForms[index];
    final startMs = _parseMs(form.startCtl.text);
    final endMs = _parseMs(form.endCtl.text);
    if (startMs == null || endMs == null) {
      return true;
    }
    if (startMs < 0 || endMs < 0) {
      showToast('구간 시간 형식을 다시 확인해 주세요.');
      return false;
    }

    const gapMs = 50;
    var adjustedStart = startMs;
    var adjustedEnd = endMs;
    var lowerBound = 0;
    var upperBound = _maxDurationMs;

    if (index > 0) {
      final prevEndMs = _parseMs(segmentForms[index - 1].endCtl.text);
      if (prevEndMs != null) {
        lowerBound = prevEndMs + gapMs;
      }
    }

    if (index < segmentForms.length - 1) {
      final nextStartMs = _parseMs(segmentForms[index + 1].startCtl.text);
      if (nextStartMs != null) {
        upperBound = nextStartMs - gapMs;
      }
    }

    if (upperBound < lowerBound) {
      upperBound = lowerBound + gapMs;
    }

    if (adjustedStart < lowerBound) {
      adjustedStart = lowerBound;
    }
    if (adjustedStart > upperBound - gapMs) {
      adjustedStart = upperBound - gapMs;
    }
    if (adjustedStart < lowerBound) {
      adjustedStart = lowerBound;
    }

    adjustedEnd = adjustedEnd.clamp(adjustedStart + gapMs, upperBound);
    if (adjustedEnd <= adjustedStart) {
      adjustedEnd = math.min(upperBound, adjustedStart + gapMs);
    }
    if (adjustedEnd <= adjustedStart) {
      adjustedStart = math.max(lowerBound, upperBound - gapMs);
      adjustedEnd = math.min(upperBound, adjustedStart + gapMs);
    }

    final tc = TimecodeService();
    final startText = tc.msToMMSSmmm(adjustedStart);
    final endText = tc.msToMMSSmmm(adjustedEnd);
    final changed =
        startText != form.startCtl.text || endText != form.endCtl.text;
    form.startCtl.value = TextEditingValue(
      text: startText,
      selection: TextSelection.collapsed(offset: startText.length),
    );
    form.endCtl.value = TextEditingValue(
      text: endText,
      selection: TextSelection.collapsed(offset: endText.length),
    );
    _syncSnapshotAt(index);
    if (changed) {
      showToast('겹침 방지를 위해 구간을 자동 조정했습니다.');
    }
    notifyListeners();
    return true;
  }

  /// 모든 세그먼트 폼 리소스를 해제합니다.
  void disposeSegmentForms() {
    for (final f in segmentForms) {
      f.dispose();
    }
    segmentForms.clear();
    _segmentSnapshots.clear();
  }

  void _syncSnapshotAt(int index) {
    if (index < 0 || index >= segmentForms.length) return;
    final form = segmentForms[index];
    final snapshot = _SegmentRangeSnapshot.fromForm(form);
    if (index < _segmentSnapshots.length) {
      _segmentSnapshots[index] = snapshot;
    } else {
      _segmentSnapshots.add(snapshot);
    }
  }

  void _writeSegmentRange(int index, int startMs, int endMs) {
    if (index < 0 || index >= segmentForms.length) return;
    final tc = TimecodeService();
    final startText = tc.msToMMSSmmm(math.max(0, startMs));
    final endText = tc.msToMMSSmmm(math.max(0, endMs));
    final form = segmentForms[index];
    form.startCtl.value = TextEditingValue(
      text: startText,
      selection: TextSelection.collapsed(offset: startText.length),
    );
    form.endCtl.value = TextEditingValue(
      text: endText,
      selection: TextSelection.collapsed(offset: endText.length),
    );
    _syncSnapshotAt(index);
  }

  int? _parseMs(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    try {
      return TimecodeService().parseToMs(text);
    } catch (_) {
      return null;
    }
  }
}

class _SegmentRangeSnapshot {
  const _SegmentRangeSnapshot({required this.start, required this.end});

  final String start;
  final String end;

  factory _SegmentRangeSnapshot.fromForm(SegmentFormData form) {
    return _SegmentRangeSnapshot(
      start: form.startCtl.text,
      end: form.endCtl.text,
    );
  }

  factory _SegmentRangeSnapshot.empty() => const _SegmentRangeSnapshot(
        start: '',
        end: '',
      );
}
