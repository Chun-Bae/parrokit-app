import 'package:cloud_firestore/cloud_firestore.dart';
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
  @override
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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
