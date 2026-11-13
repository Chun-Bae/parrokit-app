part of '../../../shell/presentation/providers/community_provider.dart';

extension CommunityProviderPost on CommunityProvider {
  List<Post> getBoardPostsByFilter(String selectedFilter) {
    final boardPosts = _posts.where((post) => post.postType == 'board');
    if (selectedFilter == '전체') {
      return boardPosts.toList();
    }
    return boardPosts.where((post) => post.category == selectedFilter).toList();
  }

  Future<void> fetchPosts({String? postType, bool refresh = false}) async {
    if (_isLoading) return;

    if (postType != null) {
      _currentPostType = postType;
    }

    if (refresh) {
      _lastDocument = null;
      _hasMorePosts = true;
      _posts.clear();
      _userCache.clear();
    }

    // 개발 빌드에서 가짜 커뮤니티를 켰으면 서버 대신 가짜 글을 보여준다.
    if (kFakeCommunity) {
      _posts = fakeCommunityPosts(_currentPostType);
      _hasMorePosts = false;
      _isLoading = false;
      _notifyListenersSafe();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    _notifyListenersSafe();

    try {
      final page = await _repository.getPosts(
        postType: _currentPostType,
        limit: CommunityProvider.postsPageSize,
        startAfter: _lastDocument,
      );

      // 전에는 커서를 받아 둘 곳이 없어서 _lastDocument가 끝까지 null이었다.
      // 그래서 startAfter도 늘 null이고, 최신 20개를 넘어가는 글은 볼
      // 방법이 없었다. 더 읽으려고 refresh 없이 다시 불러도 같은 20개가
      // 한 번 더 쌓였다.
      _lastDocument = page.lastDocument ?? _lastDocument;
      _hasMorePosts = page.hasMore;

      final visiblePosts = page.posts
          .where((post) => !_blockedUserIds.contains(post.authorId))
          .toList();
      _posts.addAll(visiblePosts);

      await _fetchMissingUsers(
        visiblePosts.map((p) => p.authorId).whereType<String>(),
      );
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      _notifyListenersSafe();
    }
  }

  /// 다음 페이지를 이어 읽는다. 더 없으면 아무것도 하지 않는다.
  ///
  /// 게시판·질문·투표 목록이 post_list_paging.dart를 통해 부른다.
  Future<void> loadMorePosts() async {
    if (_isLoading || !_hasMorePosts) return;
    await fetchPosts();
  }

  Future<void> fetchPostDetails(String postId) async {
    if (_posts.any((p) => p.id == postId)) return;

    try {
      final post = await _repository.getPostById(postId);
      if (post != null && !_blockedUserIds.contains(post.authorId)) {
        _posts = List.from(_posts)..add(post);

        await _fetchMissingUsers([post.authorId]);

        _notifyListenersSafe();
      }
    } catch (e) {
      _errorMessage = e.toString();
    }
  }

  Future<bool> addPost(
    String title,
    String content,
    String category, {
    String postType = 'board',
    required String authorId,
    required String authorNickname,
    String? authorAvatarUrl,
    List<String> tags = const [],
    List<File> imageFiles = const [],
    List<VoteOption>? voteOptions,
    DateTime? voteEndTime,
    void Function(int current, int total, double progress)? onImageProgress,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _notifyListenersSafe();

    try {
      await addPostUseCase.execute(
        title: title,
        content: content,
        category: category,
        postType: postType,
        authorId: authorId,
        authorNickname: authorNickname,
        authorAvatarUrl: authorAvatarUrl,
        tags: tags,
        imageFiles: imageFiles,
        voteOptions: voteOptions,
        voteEndTime: voteEndTime,
        onImageProgress: onImageProgress,
      );

      _isLoading = false;
      await fetchPosts(refresh: true);

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      _notifyListenersSafe();
      return false;
    }
  }

  Future<bool> editPost(
    String postId, {
    required String title,
    required String content,
    required String category,
    required List<String> tags,
    required List<String> existingImageUrls,
    required List<File> newImageFiles,
    required String authorId,
    void Function(int current, int total, double progress)? onImageProgress,
  }) async {
    if (isFakePost(postId)) return false; // 가짜 글은 서버에 쓰지 않는다

    _isLoading = true;
    _errorMessage = null;
    _notifyListenersSafe();

    try {
      // firstWhere를 orElse 없이 쓰고 있었다. 목록에 없으면 StateError가 나고,
      // 그게 그대로 _errorMessage에 담겨 "Bad state: No element"가 토스트로
      // 떴다. 글 목록은 최신 20개만 들고 있어서 못 찾는 경우가 생긴다.
      final matched = _posts.where((p) => p.id == postId);
      if (matched.isEmpty) {
        _errorMessage = '수정할 글을 찾지 못했어요. 목록을 새로고침한 뒤 다시 시도해 주세요.';
        _isLoading = false;
        _notifyListenersSafe();
        return false;
      }
      final postToEdit = matched.first;

      await editPostUseCase.execute(
        existingPost: postToEdit,
        title: title,
        content: content,
        category: category,
        tags: tags,
        existingImageUrls: existingImageUrls,
        newImageFiles: newImageFiles,
        authorId: authorId,
        onImageProgress: onImageProgress,
      );

      _isLoading = false;
      await fetchPosts(refresh: true);

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      _notifyListenersSafe();
      return false;
    }
  }

  Future<bool> deletePost(String postId) async {
    if (isFakePost(postId)) return false; // 가짜 글은 서버에 쓰지 않는다

    _isLoading = true;
    _errorMessage = null;
    _notifyListenersSafe();

    try {
      // editPost와 같은 이유로 orElse 없는 firstWhere를 쓰지 않는다.
      final matched = _posts.where((p) => p.id == postId);
      if (matched.isEmpty) {
        _errorMessage = '지울 글을 찾지 못했어요. 목록을 새로고침한 뒤 다시 시도해 주세요.';
        _isLoading = false;
        _notifyListenersSafe();
        return false;
      }
      await deletePostUseCase.execute(matched.first);
      
      _posts.removeWhere((post) => post.id == postId);

      _isLoading = false;
      _notifyListenersSafe();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      _notifyListenersSafe();
      return false;
    }
  }
}
