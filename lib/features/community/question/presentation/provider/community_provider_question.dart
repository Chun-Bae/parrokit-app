part of '../../../shell/presentation/providers/community_provider.dart';

extension CommunityProviderQuestion on CommunityProvider {
  Future<bool> addQuestion({
    required String title,
    required String content,
    required String category,
    required String authorId,
    required String authorNickname,
    required int rewardCrackers,
    required DateTime expireAt,
    String? authorAvatarUrl,
    List<String> tags = const [],
    List<File> imageFiles = const [],
    void Function(int current, int total, double progress)? onImageProgress,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _notifyListenersSafe();

    try {
      await addQuestionUseCase.execute(
        title: title,
        content: content,
        category: category,
        authorId: authorId,
        authorNickname: authorNickname,
        rewardCrackers: rewardCrackers,
        expireAt: expireAt,
        authorAvatarUrl: authorAvatarUrl,
        tags: tags,
        imageFiles: imageFiles,
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

  Future<bool> acceptAnswer({
    required String postId,
    required String commentId,
    required String answererId,
    required int rewardCrackers,
  }) async {
    if (isFakePost(postId)) return false; // 가짜 글은 서버에 쓰지 않는다

    _isLoading = true;
    _errorMessage = null;
    _notifyListenersSafe();

    try {
      await acceptAnswerUseCase.execute(
        postId: postId,
        commentId: commentId,
        answererId: answererId,
        rewardCrackers: rewardCrackers,
      );

      _isLoading = false;

      final postIndex = _posts.indexWhere((p) => p.id == postId);
      if (postIndex != -1) {
        _posts[postIndex] = _posts[postIndex].copyWith(
          questionStatus: 'resolved',
          acceptedCommentId: commentId,
        );
      }

      final commentIndex = _currentPostComments.indexWhere((c) => c.id == commentId);
      if (commentIndex != -1) {
        _currentPostComments[commentIndex] = _currentPostComments[commentIndex].copyWith(
          isAccepted: true,
        );
      }

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
