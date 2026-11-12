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
      _posts.clear();
      _userCache.clear();
    }

    _isLoading = true;
    _errorMessage = null;
    _notifyListenersSafe();

    try {
      final fetchedPosts = await _repository.getPosts(
        postType: _currentPostType,
        limit: 20,
        startAfter: _lastDocument,
      );
      _posts.addAll(
        fetchedPosts.where((post) => !_blockedUserIds.contains(post.authorId)),
      );

      await _fetchMissingUsers(
        fetchedPosts
            .where((post) => !_blockedUserIds.contains(post.authorId))
            .map((p) => p.authorId)
            .whereType<String>(),
      );
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      _notifyListenersSafe();
    }
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
