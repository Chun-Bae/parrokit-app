part of 'community_provider.dart';

extension CommunityProviderUserAction on CommunityProvider {
  bool isPostLiked(String postId) => _postLikedStates[postId] ?? false;
  bool isPostScrapped(String postId) => _postScrappedStates[postId] ?? false;

  Future<void> loadUserActionsForPosts(List<String> postIds, {String? userId}) async {
    if (postIds.isEmpty) return;
    if (userId == null) {
      for (final postId in postIds) {
        _postLikedStates[postId] = false;
        _postScrappedStates[postId] = false;
      }
      _notifyListenersSafe();
      return;
    }

    await Future.wait(postIds.map((postId) async {
      try {
        final actions = await loadUserActionsUseCase.execute(postId, userId);
        _postLikedStates[postId] = actions['isLiked'] ?? false;
        _postScrappedStates[postId] = actions['isScrapped'] ?? false;
      } catch (_) {
        _postLikedStates[postId] = false;
        _postScrappedStates[postId] = false;
      }
    }));
    _notifyListenersSafe();
  }

  Future<void> loadUserActions(String postId, {String? userId}) async {
    // 글을 열었다가 바로 다른 글을 열면 늦게 끝난 앞 글의 공감·스크랩 여부가
    // 지금 글에 표시됐고, 그 상태로 공감을 누르면 반대로 보냈다(5차).
    // 앞 글 값은 그 글 몫으로만 저장하고, 지금 글 표시는 마지막 요청만 바꾼다.
    final request = ++_userActionsRequest;

    _isCurrentPostLiked = false;
    _isCurrentPostScrapped = false;
    _notifyListenersSafe();

    if (isFakePost(postId)) return; // 가짜 글은 서버에 쓰지 않는다
    if (userId == null) return;

    try {
      final actions = await loadUserActionsUseCase.execute(postId, userId);
      final liked = actions['isLiked'] ?? false;
      final scrapped = actions['isScrapped'] ?? false;
      _postLikedStates[postId] = liked;
      _postScrappedStates[postId] = scrapped;
      if (request != _userActionsRequest) return;
      _isCurrentPostLiked = liked;
      _isCurrentPostScrapped = scrapped;
      _notifyListenersSafe();
    } catch (e) {
      // noop
    }
  }

  Future<void> incrementViewCount(String postId, {String? userId}) async {
    if (isFakePost(postId)) return; // 가짜 글은 서버에 쓰지 않는다

    try {
      final incremented = await incrementViewCountUseCase.execute(postId, userId: userId);
      if (incremented) {
        final postIndex = _posts.indexWhere((p) => p.id == postId);
        if (postIndex != -1) {
          final p = _posts[postIndex];
          _posts[postIndex] = p.copyWith(viewCount: p.viewCount + 1);
          _notifyListenersSafe();
        }
      }
    } catch (e) {
      // noop
    }
  }

  Future<void> toggleLike(String postId, String userId) async {
    if (isFakePost(postId)) return; // 가짜 글은 서버에 쓰지 않는다
    // 로그인하지 않았으면 users//likes 같은 잘못된 경로가 된다. 아무것도 하지 않는다.
    if (userId.isEmpty) return;

    _errorMessage = null;
    final originalState = _postLikedStates[postId] ?? _isCurrentPostLiked;
    final targetState = !originalState;
    _postLikedStates[postId] = targetState;
    _isCurrentPostLiked = targetState;

    final postIndex = _posts.indexWhere((p) => p.id == postId);
    if (postIndex != -1) {
      final p = _posts[postIndex];
      _posts[postIndex] = p.copyWith(likeCount: p.likeCount + (targetState ? 1 : -1));
    }
    _notifyListenersSafe();

    try {
      await toggleLikeUseCase.execute(postId, userId, targetState);
    } catch (e) {
      _isCurrentPostLiked = originalState;
      _postLikedStates[postId] = originalState;
      // await 사이에 fetchPosts·setBlockedUserIds가 _posts를 갈아끼울 수 있다.
      // 위에서 잡아 둔 postIndex를 그대로 쓰면 되돌리기가 엉뚱한 글의
      // 수를 건드린다. 다시 찾는다.
      final rollbackIndex = _posts.indexWhere((p) => p.id == postId);
      if (rollbackIndex != -1) {
        final p = _posts[rollbackIndex];
        _posts[rollbackIndex] =
            p.copyWith(likeCount: p.likeCount + (originalState ? 1 : -1));
      }
      _errorMessage = '추천 처리에 실패했습니다.';
      _notifyListenersSafe();
    }
  }

  Future<void> toggleScrap(String postId, String userId) async {
    if (isFakePost(postId)) return; // 가짜 글은 서버에 쓰지 않는다
    // 로그인하지 않았으면 users//likes 같은 잘못된 경로가 된다. 아무것도 하지 않는다.
    if (userId.isEmpty) return;

    _errorMessage = null;
    final originalState = _postScrappedStates[postId] ?? _isCurrentPostScrapped;
    final targetState = !originalState;
    _postScrappedStates[postId] = targetState;
    _isCurrentPostScrapped = targetState;

    final postIndex = _posts.indexWhere((p) => p.id == postId);
    if (postIndex != -1) {
      final p = _posts[postIndex];
      _posts[postIndex] = p.copyWith(
        scrapCount: p.scrapCount + (targetState ? 1 : -1),
      );
    }
    _notifyListenersSafe();

    try {
      await toggleScrapUseCase.execute(postId, userId, targetState);
    } catch (e) {
      _isCurrentPostScrapped = originalState;
      _postScrappedStates[postId] = originalState;
      // await 사이에 fetchPosts·setBlockedUserIds가 _posts를 갈아끼울 수 있다.
      // 위에서 잡아 둔 postIndex를 그대로 쓰면 되돌리기가 엉뚱한 글의
      // 수를 건드린다. 다시 찾는다.
      final rollbackIndex = _posts.indexWhere((p) => p.id == postId);
      if (rollbackIndex != -1) {
        final p = _posts[rollbackIndex];
        _posts[rollbackIndex] = p.copyWith(
          scrapCount: p.scrapCount + (originalState ? 1 : -1),
        );
      }
      _errorMessage = '스크랩 처리에 실패했습니다.';
      _notifyListenersSafe();
    }
  }
}
