import 'package:parrokit/features/community/shell/data/repositories/community_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ToggleLikeUseCase {
  final CommunityRepository _repository;

  ToggleLikeUseCase(this._repository);

  Future<void> execute(String postId, String userId, bool targetState) async {
    await _repository.toggleLike(postId, userId, targetState);
  }
}

class ToggleScrapUseCase {
  final CommunityRepository _repository;

  ToggleScrapUseCase(this._repository);

  Future<void> execute(String postId, String userId, bool targetState) async {
    await _repository.toggleScrap(postId, userId, targetState);
  }
}

class ToggleCommentLikeUseCase {
  final CommunityRepository _repository;

  ToggleCommentLikeUseCase(this._repository);

  Future<void> execute(
      String postId, String commentId, String userId, bool targetState) async {
    await _repository.toggleCommentLike(postId, commentId, userId, targetState);
  }
}

class LoadUserActionsUseCase {
  final CommunityRepository _repository;

  LoadUserActionsUseCase(this._repository);

  Future<Map<String, dynamic>> execute(String postId, String userId) async {
    return await _repository.getUserPostActions(postId, userId);
  }
}

class IncrementViewCountUseCase {
  final CommunityRepository _repository;

  IncrementViewCountUseCase(this._repository);

  Future<bool> execute(String postId, {String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'viewed_${userId ?? "guest"}_$postId';
    final lastViewedStr = prefs.getString(key);

    var shouldIncrement = false;

    if (lastViewedStr == null) {
      shouldIncrement = true;
    } else {
      final lastViewed = DateTime.parse(lastViewedStr);
      if (DateTime.now().difference(lastViewed).inHours >= 24) {
        shouldIncrement = true;
      }
    }

    if (shouldIncrement) {
      await _repository.incrementViewCount(postId);
      await prefs.setString(key, DateTime.now().toIso8601String());
      return true;
    }
    return false;
  }
}
