import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:parrokit/data/models/comment.dart';
import 'package:parrokit/data/models/post.dart';

part '../../../board/data/repositories/community_repository_post.dart';
part 'community_repository_comment.dart';
part 'community_repository_user_action.dart';
part '../../../question/data/repositories/community_repository_question.dart';
part '../../../vote/data/repositories/community_repository_vote.dart';

class CommunityRepository
    with
        CommunityRepositoryPost,
        CommunityRepositoryComment,
        CommunityRepositoryUserAction,
        CommunityRepositoryQuestion,
        CommunityRepositoryVote {
  /// 테스트에서 가짜 Firestore를 끼울 수 있게 받는다. 안 주면 평소대로
  /// FirebaseFirestore.instance를 쓴다.
  CommunityRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functionsOverride = functions;

  @override
  final FirebaseFirestore _firestore;
  final FirebaseFunctions? _functionsOverride;

  /// 질문 등록·답변 채택은 크래커가 오가서 서버 함수로 한다.
  /// Firestore만 넣어 만드는 테스트에서 Functions를 미리 잡지 않도록 늦게 연다.
  @override
  FirebaseFunctions get _functions =>
      _functionsOverride ?? FirebaseFunctions.instance;
  final Map<String, String> _authorNicknameCache = {};

  @override
  Future<Map<String, String>> _getAuthorNicknames(Set<String> authorIds) async {
    final nicknames = <String, String>{};
    if (authorIds.isEmpty) return nicknames;

    for (final authorId in authorIds) {
      final cachedNickname = _authorNicknameCache[authorId];
      if (cachedNickname != null && cachedNickname.isNotEmpty) {
        nicknames[authorId] = cachedNickname;
      }
    }

    final missingAuthorIds = authorIds
        .where((authorId) => !_authorNicknameCache.containsKey(authorId))
        .toList();

    if (missingAuthorIds.isEmpty) {
      return nicknames;
    }

    final idsList = missingAuthorIds;
    for (var i = 0; i < idsList.length; i += 10) {
      final end = i + 10 > idsList.length ? idsList.length : i + 10;
      final chunk = idsList.sublist(i, end);
      final snap = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final doc in snap.docs) {
        final displayName = doc.data()['displayName'] as String?;
        if (displayName != null && displayName.isNotEmpty) {
          _authorNicknameCache[doc.id] = displayName;
          nicknames[doc.id] = displayName;
        } else {
          _authorNicknameCache[doc.id] = '';
        }
      }
    }

    return nicknames;
  }
}
