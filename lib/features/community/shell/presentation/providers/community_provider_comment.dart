part of 'community_provider.dart';

extension CommunityProviderComment on CommunityProvider {
  // 이미지 로직은 CommunityImageService로 이관됨

  // 특정 게시글의 댓글 목록 가져오기 (현재 로그인된 유저 ID도 받아와서 좋아요 상태 셋팅)
  Future<void> fetchComments(String postId, {String? currentUserId}) async {
    _currentPostComments.clear();
    _replyingTo = null;

    try {
      final comments = await _repository.getComments(postId);
      _currentPostComments.addAll(comments);

      await _fetchMissingUsers(
        comments.map((c) => c.authorId).whereType<String>(),
      );

      if (currentUserId != null) {
        _likedCommentIds = await _repository.getLikedCommentIds(currentUserId);
      } else {
        _likedCommentIds.clear();
      }

      _notifyListenersSafe();
    } catch (e) {
      _errorMessage = e.toString();
      _notifyListenersSafe();
    }
  }

  Future<bool> addComment(
    String postId,
    String content, {
    required String authorId,
    required String authorNickname,
    String? authorAvatarUrl,
  }) async {
    try {
      final postIndex = _posts.indexWhere((p) => p.id == postId);
      final postType = postIndex != -1 ? _posts[postIndex].postType : 'board';

      final createdComment = await addCommentUseCase.execute(
        postId,
        content,
        postType: postType,
        authorId: authorId,
        authorNickname: authorNickname,
        authorAvatarUrl: authorAvatarUrl,
        replyingTo: _replyingTo,
      );

      _replyingTo = null;
      _currentPostComments = List.from(_currentPostComments)..add(createdComment);

      if (postIndex != -1) {
        final p = _posts[postIndex];
        _posts[postIndex] = p.copyWith(commentCount: p.commentCount + 1);
      }

      _notifyListenersSafe();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _notifyListenersSafe();
      return false;
    }
  }

  Future<bool> deleteComment(String postId, String commentId) async {
    try {
      await deleteCommentUseCase.execute(postId, commentId);

      final index = _currentPostComments.indexWhere((c) => c.id == commentId);
      if (index != -1) {
        final deletedComment = _currentPostComments[index].copyWith(
          status: 'deleted',
          content: '이 댓글은 삭제된 댓글입니다.',
        );
        _currentPostComments = List.from(_currentPostComments)..[index] = deletedComment;
      }

      _notifyListenersSafe();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _notifyListenersSafe();
      return false;
    }
  }

  Future<void> toggleCommentLike(String postId, String commentId, String userId) async {
    final isLiked = _likedCommentIds.contains(commentId);
    final targetState = !isLiked;

    if (targetState) {
      _likedCommentIds.add(commentId);
    } else {
      _likedCommentIds.remove(commentId);
    }

    final commentIndex = _currentPostComments.indexWhere((c) => c.id == commentId);
    if (commentIndex != -1) {
      final c = _currentPostComments[commentIndex];
      _currentPostComments[commentIndex] =
          c.copyWith(likeCount: c.likeCount + (targetState ? 1 : -1));
    }
    _notifyListenersSafe();

    try {
      await toggleCommentLikeUseCase.execute(postId, commentId, userId, targetState);
    } catch (e) {
      if (!targetState) {
        _likedCommentIds.add(commentId);
      } else {
        _likedCommentIds.remove(commentId);
      }
      // await 사이에 fetchComments·addComment·deleteComment가 목록을 갈아끼울 수
      // 있다. 위에서 잡아 둔 commentIndex를 그대로 쓰면 되돌리기가 엉뚱한 댓글의
      // 좋아요 수를 건드린다. 다시 찾는다.
      final rollbackIndex =
          _currentPostComments.indexWhere((c) => c.id == commentId);
      if (rollbackIndex != -1) {
        final c = _currentPostComments[rollbackIndex];
        _currentPostComments[rollbackIndex] =
            c.copyWith(likeCount: c.likeCount + (!targetState ? 1 : -1));
      }
      _errorMessage = e.toString();
      _notifyListenersSafe();
    }
  }
}
