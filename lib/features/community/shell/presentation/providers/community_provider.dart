// lib/features/community/shell/providers/community_provider.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parrokit/core/infrastructure/services/firebase/firebase_user_service.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:parrokit/data/models/post.dart';
import 'package:parrokit/data/models/comment.dart';
import 'package:parrokit/data/models/user.dart';
import 'package:parrokit/data/models/vote_option.dart';
import 'package:parrokit/features/community/shell/data/repositories/community_repository.dart';
import 'package:parrokit/features/community/shell/data/services/community_image_service.dart';
import 'package:parrokit/features/community/shell/domain/usecases/post/add_post_usecase.dart';
import 'package:parrokit/features/community/shell/domain/usecases/post/edit_post_usecase.dart';
import 'package:parrokit/features/community/shell/domain/usecases/post/delete_post_usecase.dart';
import 'package:parrokit/features/community/shell/domain/usecases/comment/add_comment_usecase.dart';
import 'package:parrokit/features/community/shell/domain/usecases/comment/delete_comment_usecase.dart';
import 'package:parrokit/features/community/shell/domain/usecases/question/add_question_usecase.dart';
import 'package:parrokit/features/community/shell/domain/usecases/question/accept_answer_usecase.dart';
import 'package:parrokit/features/community/shell/domain/usecases/vote/vote_post_usecase.dart';
import 'package:parrokit/features/community/shell/domain/usecases/user_action/user_action_usecases.dart';
import 'dart:io';

part '../../../board/presentation/provider/community_provider_post.dart';
part '../../../vote/presentation/provider/community_provider_vote.dart';
part 'community_provider_comment.dart';
part 'community_provider_user_action.dart';
part '../../../question/presentation/provider/community_provider_question.dart';

class CommunityProvider with ChangeNotifier {
  final CommunityRepository _repository = CommunityRepository();
  final CommunityImageService _imageService = CommunityImageService();
  final FirebaseUserService _userService = FirebaseUserService();

  late final AddPostUseCase addPostUseCase = AddPostUseCase(_repository, _imageService);
  late final EditPostUseCase editPostUseCase = EditPostUseCase(_repository, _imageService);
  late final DeletePostUseCase deletePostUseCase = DeletePostUseCase(_repository, _imageService);
  late final AddCommentUseCase addCommentUseCase = AddCommentUseCase(_repository);
  late final DeleteCommentUseCase deleteCommentUseCase = DeleteCommentUseCase(_repository);
  late final AddQuestionUseCase addQuestionUseCase = AddQuestionUseCase(_repository, _imageService);
  late final AcceptAnswerUseCase acceptAnswerUseCase = AcceptAnswerUseCase(_repository);
  late final VotePostUseCase votePostUseCase = VotePostUseCase(_repository);
  late final ToggleLikeUseCase toggleLikeUseCase = ToggleLikeUseCase(_repository);
  late final ToggleScrapUseCase toggleScrapUseCase = ToggleScrapUseCase(_repository);
  late final ToggleCommentLikeUseCase toggleCommentLikeUseCase = ToggleCommentLikeUseCase(_repository);
  late final LoadUserActionsUseCase loadUserActionsUseCase = LoadUserActionsUseCase(_repository);
  late final IncrementViewCountUseCase incrementViewCountUseCase = IncrementViewCountUseCase(_repository);

  final Map<String, AppUser> _userCache = {};
  Set<String> _blockedUserIds = {};

  void setBlockedUserIds(Iterable<String> blockedUserIds) {
    final nextBlockedUserIds = blockedUserIds.where((id) => id.isNotEmpty).toSet();
    if (setEquals(_blockedUserIds, nextBlockedUserIds)) {
      return;
    }

    _blockedUserIds = nextBlockedUserIds;
    _posts = _posts.where((post) => !_isBlockedAuthor(post.authorId)).toList();
    _currentPostComments =
        _currentPostComments.where((comment) => !_isBlockedAuthor(comment.authorId)).toList();
    Future.microtask(notifyListeners);
  }

  bool isAuthorBlocked(String authorId) => _blockedUserIds.contains(authorId);

  bool _isBlockedAuthor(String authorId) => _blockedUserIds.contains(authorId);

  AppUser? getCachedUser(String uid) => _userCache[uid];

  Future<void> _fetchMissingUsers(Iterable<String> uids) async {
    final missingUids =
        uids.where((uid) => !_userCache.containsKey(uid) && uid.isNotEmpty).toSet();
    if (missingUids.isEmpty) return;

    await Future.wait(missingUids.map((uid) async {
      try {
        final user = await _userService.loadUserDocument(uid: uid);
        if (user != null) {
          _userCache[uid] = user;
        } else {
          _userCache[uid] = AppUser(id: uid, displayName: '알 수 없음', email: '');
        }
      } catch (e) {
        // 캐시에 아무것도 넣지 않으므로 다음 렌더에서 이 uid를 다시 불러온다.
        // 일시적인 오류(오프라인 등)에는 그게 맞지만, 계속 실패하면 목록이
        // 다시 그려질 때마다 Firestore를 읽는다. 조용히 넘기지는 않는다.
        AppLogger.w('[CommunityProvider] 작성자 정보 불러오기 실패 uid=$uid: $e');
      }
    }));
  }

  List<Post> _posts = [];
  List<Post> get posts => _posts;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  DocumentSnapshot? _lastDocument;

  List<Comment> _currentPostComments = [];
  List<Comment> get currentPostComments => _currentPostComments;

  Set<String> _likedCommentIds = {};
  Set<String> get likedCommentIds => _likedCommentIds;

  Map<String, int> myVotes = {};

  Comment? _replyingTo;
  Comment? get replyingTo => _replyingTo;

  void setReplyingTo(Comment? comment) {
    _replyingTo = comment;
    notifyListeners();
  }

  bool _isCurrentPostLiked = false;
  bool get isCurrentPostLiked => _isCurrentPostLiked;

  bool _isCurrentPostScrapped = false;
  bool get isCurrentPostScrapped => _isCurrentPostScrapped;
  final Map<String, bool> _postLikedStates = {};
  final Map<String, bool> _postScrappedStates = {};

  String _currentPostType = 'board';

  /// 이름에 Safe가 붙어 있지만 여기서는 아무것도 막지 않는다. 그냥
  /// notifyListeners()다. 커뮤니티 기능 전체에서 쉰 곳 넘게 부른다.
  ///
  /// 같은 이름의 메서드가 CommunityNotificationProvider에도 있고 그쪽은
  /// `if (_isActive && hasListeners)`로 실제로 막는다. 이름이 같아서
  /// 이쪽도 막아 준다고 읽기 쉬우니 적어 둔다.
  ///
  /// 지금은 CommunityProvider가 앱 루트에 한 번 만들어지는 Provider라
  /// dispose 뒤에 불릴 일이 사실상 없어서 그대로 뒀다. 화면마다 만드는
  /// 구조로 바뀌면 여기에 실제 가드가 필요하다.
  void _notifyListenersSafe() {
    notifyListeners();
  }

  void clear() {
    _posts.clear();
    _isLoading = false;
    _errorMessage = null;
    _lastDocument = null;
    _currentPostComments.clear();
    _likedCommentIds.clear();
    _replyingTo = null;
    _isCurrentPostLiked = false;
    _isCurrentPostScrapped = false;
    _postLikedStates.clear();
    _postScrappedStates.clear();
    myVotes.clear();
    notifyListeners();
  }
}
