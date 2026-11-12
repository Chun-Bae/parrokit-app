// ============================================================================
// lib/features/_content/shorts/presentation/providers/shorts_provider.dart
// ============================================================================
//
// [역할]
// 쇼츠(Shorts) 화면의 UI 상태 및 데이터 로딩 관리.
//
// [레이어]
// Presentation Layer > Provider (ViewModel)
//
// ============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:parrokit/features/collection/clip/shorts/data/shorts_repository.dart';
import 'package:parrokit/data/models/clip_item.dart';
import 'package:parrokit/core/state/provider/clip_provider.dart';

/// [역할]
/// 쇼츠(Shorts) 화면의 UI 상태 및 데이터 로딩 관리.
///
/// 데이터 로딩은 [ShortsRepository]에 위임합니다.
/// - 자동 재생 설정(AutoNext) 관리
/// - 무한 스크롤(LoadMore) / 새로고침 관리
class ShortsProvider extends ChangeNotifier {
  final ShortsRepository _repository;
  final ClipProvider _clipProvider;

  ShortsProvider(this._repository, this._clipProvider);

  // ─────────────────────────────────────────────────────────────────
  // State
  // ─────────────────────────────────────────────────────────────────
  final List<ClipItem> _shorts = [];

  /// 표시할 클립 데이터 목록
  List<ClipItem> get shorts => List.unmodifiable(_shorts);

  bool _autoNext = true;

  /// 영상 종료 시 다음 영상 자동 재생 여부
  bool get autoNext => _autoNext;

  bool _loading = false;

  /// 데이터 로딩 중 여부
  bool get loading => _loading;

  bool _warmupRunning = false;
  int _warmupGeneration = 0;
  int _lastPrefetchAtLength = -1;
  final List<int> _warmupQueue = [];

  /// 한 번에 로드할 클립 개수 (배치 크기)
  static const int pageSize = 10;

  // ─────────────────────────────────────────────────────────────────
  // Actions
  // ─────────────────────────────────────────────────────────────────

  void toggleAutoNext() {
    _autoNext = !_autoNext;
    notifyListeners();
  }

  void setAutoNext(bool value) {
    if (_autoNext == value) return;
    _autoNext = value;
    notifyListeners();
  }

  /// 초기 데이터 로드 (첫 진입 또는 완전 초기화 시).
  ///
  /// 기존에 로드된 클립 목록을 모두 비우고([clear]),
  /// 새로운 랜덤 클립을 [limit]만큼 로드하여 채웁니다.
  /// 화면 진입 시 한 번 호출됩니다.
  Future<void> loadInitial() async {
    _resetWarmupState();
    _shorts.clear();
    await _loadRandomClips(limit: pageSize);
  }

  /// 목록 새로고침.
  ///
  /// 사용자가 당겨서 새로고침(Pull-to-refresh)을 수행할 때 사용됩니다.
  /// [loadInitial]과 유사하게 목록을 비우고 다시 로드합니다.
  Future<void> refresh() async {
    _resetWarmupState();
    _shorts.clear();
    await _loadRandomClips(limit: pageSize);
  }

  /// 추가 데이터 로드 (무한 스크롤).
  ///
  /// 현재 목록의 끝에 도달했을 때 추가로 랜덤 클립을 로드하여 붙입니다.
  /// 이미 로딩 중이면 중복 요청을 무시합니다.
  Future<void> loadMore() async {
    await _loadRandomClips(limit: pageSize);
  }

  /// 현재 로드된 목록의 끝에서 5개 이내로 들어오면 다음 배치를 미리
  /// 불러옵니다. 절대 인덱스(예: 5, 15, 25...)가 아니라 "현재 길이 기준
  /// 상대 위치"로 판단합니다 — 클립이 6개 미만이면 PageView의 itemCount가
  /// 그보다 작아서 절대 인덱스 5에 아예 도달할 수 없고, 그러면 다음 배치를
  /// 영영 불러오지 못해 클립 10개 이하일 때의 랜덤 반복 재생이 멈춥니다.
  Future<void> prefetchNextBatch(int currentIndex) async {
    if (currentIndex < 0) return;
    final total = _shorts.length;
    if (total == 0 || currentIndex < total - 5) return;
    if (_lastPrefetchAtLength == total) return;
    _lastPrefetchAtLength = total;

    await loadMore();
  }

  /// [ShortsRepository]를 통해 랜덤 클립을 로드하여 목록에 추가
  Future<void> _loadRandomClips({required int limit}) async {
    if (_loading) return;
    _loading = true;
    notifyListeners();
    try {
      final newClips = await _repository.getRandomClips(limit: limit);

      if (newClips.isNotEmpty) {
        _shorts.addAll(newClips);
        _enqueueWarmup(newClips);
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// 리스트의 앞부분 [count]개를 삭제합니다.
  ///
  /// 무한 롤링(Cycle Refresh) 구현 시, 이전 배치를 제거하고
  /// 인덱스를 초기화하기 위해 사용됩니다.
  void removeItems(int count) {
    if (count <= 0 || count > _shorts.length) return;
    _shorts.removeRange(0, count);

    // prefetchNextBatch는 "이 길이에서는 이미 당겨왔다"를 _lastPrefetchAtLength로
    // 기억한다. 여기서 길이가 줄어드는 건 미리 불러왔기 때문이 아니라 앞 배치를
    // 버렸기 때문이므로, 그 기억은 더 이상 맞지 않는다. 지우지 않으면
    // 줄어든 길이가 마침 기억된 값과 같을 때 다음 배치를 영영 못 불러온다.
    //
    // 실제로 그렇게 됐다. 10개 로드 → 5번에서 당겨서 20개 → 10번에서 앞 10개
    // 버리면 길이가 다시 10인데 _lastPrefetchAtLength도 10이다. 그 뒤로는
    // 무한 스크롤이 멈추고 같은 10개만 돌았다.
    _lastPrefetchAtLength = -1;

    notifyListeners();
  }

  void _resetWarmupState() {
    _warmupGeneration++;
    _warmupQueue.clear();
    _warmupRunning = false;
    _lastPrefetchAtLength = -1;
  }

  void _enqueueWarmup(List<ClipItem> items) {
    final queuedIds = _warmupQueue.toSet();
    for (final item in items) {
      if (queuedIds.add(item.clip.id)) {
        _warmupQueue.add(item.clip.id);
      }
    }
    unawaited(_drainWarmupQueue(_warmupGeneration));
  }

  Future<void> _drainWarmupQueue(int generation) async {
    if (_warmupRunning) return;
    _warmupRunning = true;
    try {
      while (_warmupQueue.isNotEmpty) {
        if (generation != _warmupGeneration) return;

        final clipId = _warmupQueue.removeAt(0);
        try {
          await _clipProvider.fetchClipById(clipId);
        } catch (_) {
          // 원격 캐시 실패는 쇼츠 진입을 막지 않음
        }
      }
    } finally {
      _warmupRunning = false;
    }
  }
}
