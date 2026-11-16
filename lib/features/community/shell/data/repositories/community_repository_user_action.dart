part of 'community_repository.dart';

mixin CommunityRepositoryUserAction {
  FirebaseFirestore get _firestore;

  Future<void> incrementViewCount(String postId) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'viewCount': FieldValue.increment(1),
      });
    } catch (e) {
      throw Exception('조회수 증가에 실패했습니다: $e');
    }
  }

  Future<void> toggleLike(String postId, String userId, bool isLiked) async {
    try {
      final postRef = _firestore.collection('posts').doc(postId);
      final likeRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('likes')
          .doc(postId);

      await _firestore.runTransaction((transaction) async {
        if (isLiked) {
          transaction.set(likeRef, {'createdAt': FieldValue.serverTimestamp()});
          transaction.update(postRef, {'likeCount': FieldValue.increment(1)});
        } else {
          transaction.delete(likeRef);
          transaction.update(postRef, {'likeCount': FieldValue.increment(-1)});
        }
      });
    } catch (e) {
      throw Exception('추천 처리에 실패했습니다: $e');
    }
  }

  Future<void> toggleScrap(
      String postId, String userId, bool isScrapped) async {
    try {
      final postRef = _firestore.collection('posts').doc(postId);
      final scrapRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('scraps')
          .doc(postId);

      await _firestore.runTransaction((transaction) async {
        if (isScrapped) {
          transaction
              .set(scrapRef, {'createdAt': FieldValue.serverTimestamp()});
          transaction.update(postRef, {'scrapCount': FieldValue.increment(1)});
        } else {
          transaction.delete(scrapRef);
          transaction.update(postRef, {'scrapCount': FieldValue.increment(-1)});
        }
      });
    } catch (e) {
      throw Exception('스크랩 처리에 실패했습니다: $e');
    }
  }

  Future<Map<String, bool>> getUserPostActions(
      String postId, String userId) async {
    try {
      final likeDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('likes')
          .doc(postId)
          .get();
      final scrapDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('scraps')
          .doc(postId)
          .get();

      return {
        'isLiked': likeDoc.exists,
        'isScrapped': scrapDoc.exists,
      };
    } catch (_) {
      return {
        'isLiked': false,
        'isScrapped': false,
      };
    }
  }
}
