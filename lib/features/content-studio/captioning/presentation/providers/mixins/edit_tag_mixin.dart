// ============================================================================
// lib/features/content-studio/captioning/presentation/providers/mixins/edit_tag_mixin.dart
// ============================================================================
//
// [역할]
// 태그 관리 mixin.
//
// [레이어]
// Presentation Layer > Provider > Mixin
// ============================================================================

import 'package:flutter/foundation.dart';

/// 태그 관리 mixin.
mixin EditTagMixin on ChangeNotifier {
  // ─────────────────────────────────────────────────────────────────
  // 상태
  // ─────────────────────────────────────────────────────────────────
  final List<String> tags = [];

  // ─────────────────────────────────────────────────────────────────
  // 태그 관리
  // ─────────────────────────────────────────────────────────────────

  /// 태그 하나를 추가합니다 (중복 방지).
  ///
  /// 더했으면 true. 비었거나 이미 있는 태그면 false를 돌려준다(5차 361).
  /// 전에는 아무 말 없이 돌아와서, 이미 넣은 태그를 다시 적으면 칸만
  /// 비워지고 아무 일도 일어나지 않은 것처럼 보였다.
  bool addTag(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isEmpty || tags.contains(trimmed)) return false;
    tags.add(trimmed);
    notifyListeners();
    return true;
  }

  /// 태그 하나를 제거합니다.
  void removeTag(String tag) {
    tags.remove(tag);
    notifyListeners();
  }

  /// 모든 태그를 제거합니다.
  void clearTags() {
    tags.clear();
    notifyListeners();
  }
}
