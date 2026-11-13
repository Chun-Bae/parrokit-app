part of '../../../shell/presentation/providers/community_provider.dart';

extension CommunityProviderVote on CommunityProvider {
  Future<Set<String>> getVotedPostIdSet(String userId) async {
    final votedPostIds = await _repository.getVotedPostIds(userId);
    return votedPostIds.toSet();
  }

  // 여러 투표글에 대한 내 투표 기록 일괄 조회 및 캐싱
  Future<void> fetchMyVotes(String userId) async {
    final votePosts = _posts.where((p) => p.postType == 'vote').map((p) => p.id).toList();
    if (votePosts.isEmpty) return;

    final fetchedVotes = await _repository.getMyVotes(userId, votePosts);
    myVotes.addAll(fetchedVotes);
    _notifyListenersSafe();
  }

  Future<void> ensureVotedPostsLoaded(String userId) async {
    final votedPostIds = await _repository.getVotedPostIds(userId);
    if (votedPostIds.isEmpty) {
      myVotes.clear();
      _notifyListenersSafe();
      return;
    }

    for (final postId in votedPostIds) {
      if (_posts.any((p) => p.id == postId)) continue;
      await fetchPostDetails(postId);
    }

    final fetchedVotes = await _repository.getMyVotes(userId, votedPostIds);
    myVotes
      ..clear()
      ..addAll(fetchedVotes);
    _notifyListenersSafe();
  }

  // 투표하기 (낙관적 UI 업데이트 포함)
  Future<bool> votePost(String postId, int optionIndex, String userId) async {
    // 가짜 글(개발 빌드 전용)은 서버에 쓰지 않고 앱 안에서만 반영해 결과 화면을
    // 볼 수 있게 한다. 예전엔 바로 끝나서 투표해도 아무 변화가 없었다.
    final fake = isFakePost(postId);

    _isLoading = true;
    _errorMessage = null;
    final previousOption = myVotes[postId];
    myVotes[postId] = optionIndex;
    _notifyListenersSafe();

    try {
      if (!fake) await votePostUseCase.execute(postId, userId, optionIndex);

      final postIndex = _posts.indexWhere((p) => p.id == postId);
      if (postIndex != -1) {
        final post = _posts[postIndex];
        if (post.voteOptions != null) {
          final newOptions = List<VoteOption>.from(post.voteOptions!);
          if (optionIndex >= 0 && optionIndex < newOptions.length) {
            newOptions[optionIndex] = VoteOption(
              id: newOptions[optionIndex].id,
              text: newOptions[optionIndex].text,
              count: newOptions[optionIndex].count + 1,
            );
            _posts[postIndex] = post.copyWith(voteOptions: newOptions);
          }
        }
      }

      _isLoading = false;
      _notifyListenersSafe();
      return true;
    } catch (e) {
      if (previousOption == null) {
        myVotes.remove(postId);
      } else {
        myVotes[postId] = previousOption;
      }
      _isLoading = false;
      _errorMessage = e.toString();
      _notifyListenersSafe();
      return false;
    }
  }
}
