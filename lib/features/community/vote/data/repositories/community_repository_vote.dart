part of '../../../shell/data/repositories/community_repository.dart';

mixin CommunityRepositoryVote {
  FirebaseFirestore get _firestore;

  Future<void> votePost(String postId, String userId, int optionIndex) async {
    final postRef = _firestore.collection('posts').doc(postId);
    final voterRef = postRef.collection('voters').doc(userId);
    final userVotedPostRef =
        _firestore.collection('users').doc(userId).collection('voted_posts').doc(postId);

    try {
      await _firestore.runTransaction((transaction) async {
        final postSnapshot = await transaction.get(postRef);
        final voterSnapshot = await transaction.get(voterRef);

        if (!postSnapshot.exists) {
          throw Exception('게시글을 찾을 수 없습니다.');
        }
        if (voterSnapshot.exists) {
          throw Exception('이미 투표한 게시글입니다.');
        }

        final postData = postSnapshot.data()!;
        final voteOptionsList = postData['voteOptions'] as List<dynamic>?;
        if (voteOptionsList == null) {
          throw Exception('투표 항목이 존재하지 않습니다.');
        }

        final updatedOptions = List<Map<String, dynamic>>.from(voteOptionsList);
        if (optionIndex < 0 || optionIndex >= updatedOptions.length) {
          throw Exception('유효하지 않은 투표 항목입니다.');
        }

        updatedOptions[optionIndex]['count'] =
            (updatedOptions[optionIndex]['count'] as int? ?? 0) + 1;

        transaction.update(postRef, {'voteOptions': updatedOptions});
        transaction.set(voterRef, {
          'userId': userId,
          'selectedOption': optionIndex,
          'votedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(userVotedPostRef, {
          'postId': postId,
          'selectedOption': optionIndex,
          'votedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      throw Exception('투표 처리에 실패했습니다: $e');
    }
  }

  Future<Map<String, int>> getMyVotes(String userId, List<String> postIds) async {
    final myVotes = <String, int>{};
    if (postIds.isEmpty) return myVotes;

    try {
      for (var i = 0; i < postIds.length; i += 10) {
        final end = i + 10 > postIds.length ? postIds.length : i + 10;
        final chunk = postIds.sublist(i, end);
        final snapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('voted_posts')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snapshot.docs) {
          final selectedOption = (doc.data()['selectedOption'] as num?)?.toInt();
          if (selectedOption != null) {
            myVotes[doc.id] = selectedOption;
          }
        }
      }
      return myVotes;
    } catch (e) {
      // 실패하면 "아직 투표 안 함"으로 보인다. 그 상태로 누르면 서버가
      // "이미 투표한 게시글입니다"로 거절해서 사용자가 영문을 모른다.
      AppLogger.w('[CommunityRepository] 내 투표 기록 불러오기 실패 userId=$userId: $e');
      return myVotes;
    }
  }

  Future<List<String>> getVotedPostIds(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('voted_posts')
          .get();
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      AppLogger.w('[CommunityRepository] 투표한 글 목록 불러오기 실패 userId=$userId: $e');
      return const [];
    }
  }
}
