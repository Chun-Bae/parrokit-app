part of '../../../shell/data/repositories/community_repository.dart';

mixin CommunityRepositoryPost {
  FirebaseFirestore get _firestore;
  Future<Map<String, String>> _getAuthorNicknames(Set<String> authorIds);

  Future<Post?> getPostById(String postId) async {
    try {
      final doc = await _firestore.collection('posts').doc(postId).get();
      if (!doc.exists) return null;
      return Post.fromJson(doc.data() as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  String generatePostId() {
    return _firestore.collection('posts').doc().id;
  }

  Future<Post> addPost(Post post) async {
    try {
      final docRef = post.id.isEmpty
          ? _firestore.collection('posts').doc()
          : _firestore.collection('posts').doc(post.id);

      final newPost = post.copyWith(
        id: docRef.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await docRef.set(newPost.toJson());
      return newPost;
    } catch (e) {
      throw Exception('게시글 등록에 실패했습니다: $e');
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      await _firestore.collection('posts').doc(postId).delete();
    } catch (e) {
      throw Exception('게시글 삭제에 실패했습니다: $e');
    }
  }

  Future<void> updatePost(String postId, Map<String, dynamic> data) async {
    try {
      final now = DateTime.now().toIso8601String();
      data['updatedAt'] = now;
      data['editHistory'] = FieldValue.arrayUnion([now]);

      await _firestore.collection('posts').doc(postId).update(data);
    } catch (e) {
      throw Exception('게시글 수정에 실패했습니다: $e');
    }
  }

  /// 한 페이지의 글과, 다음 페이지를 읽기 위한 커서.
  ///
  /// 전에는 글 목록만 돌려줬다. 그래서 CommunityProvider의 _lastDocument에
  /// 넣을 값이 없었고, 그 값은 선언만 되어 있고 끝까지 null이었다. 결과로
  /// 게시판·질문·투표가 각각 최신 20개까지만 보이고 그 뒤를 볼 방법이
  /// 없었다.
  Future<PostPage> getPosts({
    String postType = 'board',
    int limit = 10,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _firestore
          .collection('posts')
          .where('postType', isEqualTo: postType)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      final docs = snapshot.docs;

      final authorIds = <String>{};
      for (final doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        final authorId = data['authorId'] as String?;
        if (authorId != null) {
          authorIds.add(authorId);
        }
      }

      final nicknames = await _getAuthorNicknames(authorIds);

      final posts = docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        final authorId = data['authorId'] as String?;
        if (authorId != null && nicknames.containsKey(authorId)) {
          data['authorNickname'] = nicknames[authorId];
        }
        return Post.fromJson(data);
      }).toList();

      return PostPage(
        posts: posts,
        lastDocument: docs.isEmpty ? null : docs.last,
        // 요청한 만큼 꽉 채워 왔으면 뒤에 더 있을 수 있다는 뜻이다.
        // 정확히 배수로 끝나면 마지막에 빈 페이지를 한 번 읽는다.
        hasMore: docs.length == limit,
      );
    } catch (e) {
      throw Exception('게시글을 불러오는데 실패했습니다: $e');
    }
  }
}

/// getPosts의 한 페이지.
class PostPage {
  const PostPage({
    required this.posts,
    required this.lastDocument,
    required this.hasMore,
  });

  final List<Post> posts;

  /// 다음 페이지를 읽을 때 startAfter로 넘길 문서. 이 페이지가 비면 null이다.
  final DocumentSnapshot? lastDocument;

  final bool hasMore;
}
