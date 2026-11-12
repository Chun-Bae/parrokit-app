import 'package:flutter/material.dart';
import '../../domain/entities/activity_item.dart';
import '../../domain/entities/activity_cursor.dart';
import '../../domain/usecases/get_activities_usecase.dart';
import '../../data/repositories/activity_repository_impl.dart';

class ActivityProvider extends ChangeNotifier {
  final GetActivitiesUseCase _getActivitiesUseCase;

  ActivityProvider({GetActivitiesUseCase? getActivitiesUseCase})
      : _getActivitiesUseCase = getActivitiesUseCase ?? GetActivitiesUseCase(ActivityRepositoryImpl());

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  List<ActivityItem> _activities = [];
  List<ActivityItem> get activities => _activities;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  ActivityCursor? _nextCursor;
  String? _userId;
  String? _boardType;
  String? _activityType;
  static const int _pageSize = 20;

  Future<void> fetchActivities({
    required String userId,
    required String boardType,
    required String activityType,
  }) async {
    _userId = userId;
    _boardType = boardType;
    _activityType = activityType;
    _nextCursor = null;
    _hasMore = true;
    _activities = [];
    await _loadPage(reset: true);
  }

  Future<void> refresh() async {
    if (_userId == null || _boardType == null || _activityType == null) return;
    await fetchActivities(
      userId: _userId!,
      boardType: _boardType!,
      activityType: _activityType!,
    );
  }

  Future<void> loadMore() async {
    if (_userId == null || _boardType == null || _activityType == null) return;
    if (_isLoadingMore || !_hasMore) return;
    await _loadPage();
  }

  /// 조회 요청 번호. 탭이나 필터를 바꾸면 올라간다.
  /// 앞선 조회가 늦게 끝나도 새 목록에 섞이지 않게 하려는 것이다.
  int _loadRequestId = 0;

  Future<void> _loadPage({bool reset = false}) async {
    if (_userId == null || _boardType == null || _activityType == null) return;

    final requestId = ++_loadRequestId;

    _isLoading = true;
    _isLoadingMore = !reset;
    _error = null;
    notifyListeners();

    try {
      final page = await _getActivitiesUseCase(
        userId: _userId!,
        boardType: _boardType!,
        activityType: _activityType!,
        limit: _pageSize,
        startAfter: _nextCursor,
      );

      // 기다리는 동안 탭이 바뀌었으면 이 결과는 버린다. loadMore가 도는 중에
      // 사용자가 다른 활동 유형으로 넘어가면, 늦게 끝난 옛 조회가 새 목록
      // 뒤에 엉뚱한 항목을 붙이고 커서까지 덮어쓴다.
      if (requestId != _loadRequestId) return;

      if (reset) {
        _activities = page.items;
      } else {
        _activities = [..._activities, ...page.items];
      }
      _hasMore = page.hasMore;
      _nextCursor = page.nextCursor;
    } catch (e) {
      if (requestId != _loadRequestId) return;
      _error = e.toString();
    } finally {
      if (requestId == _loadRequestId) {
        _isLoading = false;
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }
}
