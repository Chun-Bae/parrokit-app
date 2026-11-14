import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parrokit/core/shared/utils/app_logger.dart';
import 'package:parrokit/data/models/comment.dart';
import 'package:parrokit/data/models/post.dart';

import '../../domain/entities/activity_cursor.dart';
import '../../domain/entities/activity_page.dart';
import '../../domain/repositories/activity_repository.dart';
import '../models/activity_model.dart';

class ActivityRepositoryImpl implements ActivityRepository {
  final FirebaseFirestore _firestore;

  ActivityRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<ActivityPage> getActivities({
    required String userId,
    required String boardType,
    required String activityType,
    int limit = 100,
    ActivityCursor? startAfter,
  }) async {
    if (userId.isEmpty) {
      return const ActivityPage(items: [], hasMore: false);
    }

    final activities = <ActivityModel>[];
    ActivityCursor? nextCursor;
    var hasMore = false;

    try {
      if (activityType == 'written' || activityType == 'written_posted') {
        if (boardType == 'vote' && activityType == 'written') {
          final query = _firestore
              .collection('users')
              .doc(userId)
              .collection('voted_posts')
              .orderBy('votedAt', descending: true)
              .limit(limit);

          final snap = await _applyCursor(
            query: query,
            cursor: startAfter,
            cursorField: 'votedAt',
          ).get();

          final votedAtByPostId = <String, DateTime>{};
          for (final doc in snap.docs) {
            votedAtByPostId[doc.id] = _parseDateTime(doc.data()['votedAt']);
          }

          final votePosts = await _fetchPostsByIds(snap.docs.map((doc) => doc.id).toList());
          final votePostMap = {for (final post in votePosts) post.id: post};

          for (final doc in snap.docs) {
            final post = votePostMap[doc.id];
            if (post == null || post.postType != 'vote') continue;
            activities.add(
              _postToActivity(
                post,
                activityType,
                createdAtOverride: votedAtByPostId[doc.id],
              ),
            );
          }

          if (snap.docs.isNotEmpty) {
            nextCursor = _makeCursor(
              snap.docs.last,
              fieldName: 'votedAt',
            );
          }
          hasMore = snap.docs.length == limit;
        } else {
          final query = _firestore
              .collection('posts')
              .where('authorId', isEqualTo: userId)
              .where('postType', isEqualTo: boardType)
              .orderBy('createdAt', descending: true)
              .limit(limit);

          final snap = await _applyCursor(
            query: query,
            cursor: startAfter,
            cursorField: 'createdAt',
          ).get();
          final fallbackPage = await _fetchFallbackPostDocs(
            userId: userId,
            boardType: boardType,
            limit: limit,
            startAfter: startAfter,
          );
          final docs = snap.docs.isNotEmpty ? snap.docs : fallbackPage.docs;

          for (final doc in docs) {
            final post = Post.fromJson({
              'id': doc.id,
              ..._normalizeFirestoreMap(doc.data()),
            });
            activities.add(_postToActivity(post, activityType));
          }

          if (docs.isNotEmpty) {
            nextCursor = _makeCursor(
              docs.last,
              fieldName: 'createdAt',
            );
          }
          hasMore = snap.docs.isNotEmpty ? snap.docs.length == limit : fallbackPage.hasMore;
        }
      } else if (activityType == 'commented' || activityType == 'commented_reply') {
        final query = _firestore
            .collectionGroup('comments')
            .where('authorId', isEqualTo: userId)
            .where('postType', isEqualTo: boardType)
            .orderBy('createdAt', descending: true)
            .limit(limit);

        final snap = await _applyCursor(
          query: query,
          cursor: startAfter,
          cursorField: 'createdAt',
        ).get();

        for (final doc in snap.docs) {
          final comment = Comment.fromJson({
            'id': doc.id,
            'postId': doc.reference.parent.parent?.id ?? '',
            ..._normalizeFirestoreMap(doc.data()),
          });

          final isQuestionAnswer =
              boardType == 'question' && comment.parentId == null;
          final isQuestionReply =
              boardType == 'question' && comment.parentId != null;

          if (activityType == 'commented' &&
              boardType == 'question' &&
              !isQuestionAnswer) {
            continue;
          }
          if (activityType == 'commented_reply' &&
              boardType == 'question' &&
              !isQuestionReply) {
            continue;
          }
          if (activityType == 'commented_reply' && boardType != 'question') {
            continue;
          }

          activities.add(_commentToActivity(comment, activityType));
        }

        if (snap.docs.isNotEmpty) {
          nextCursor = _makeCursor(
            snap.docs.last,
            fieldName: 'createdAt',
          );
        }
        hasMore = snap.docs.length == limit;
      } else if (activityType == 'liked') {
        final query = _firestore
            .collection('users')
            .doc(userId)
            .collection('likes')
            .orderBy('createdAt', descending: true)
            .limit(limit);

        final snap = await _applyCursor(
          query: query,
          cursor: startAfter,
          cursorField: 'createdAt',
        ).get();

        final postIds = snap.docs.map((doc) => doc.id).toList();
        if (postIds.isNotEmpty) {
          final posts = await _fetchPostsByIds(postIds);
          final postMap = {for (final post in posts) post.id: post};
          for (final id in postIds) {
            final post = postMap[id];
            if (post == null || post.postType != boardType) continue;
            activities.add(_postToActivity(post, activityType));
          }
        }

        if (snap.docs.isNotEmpty) {
          nextCursor = _makeCursor(
            snap.docs.last,
            fieldName: 'createdAt',
          );
        }
        hasMore = snap.docs.length == limit;
      } else if (activityType == 'liked_comment') {
        final query = _firestore
            .collection('users')
            .doc(userId)
            .collection('comment_likes')
            .orderBy('createdAt', descending: true)
            .limit(limit);

        final snap = await _applyCursor(
          query: query,
          cursor: startAfter,
          cursorField: 'createdAt',
        ).get();

        for (final likeDoc in snap.docs) {
          final likeData = likeDoc.data();
          final postId = likeData['postId'] as String?;
          final commentId = likeData['commentId'] as String?;
          if (postId == null || commentId == null) {
            continue;
          }
          final commentDoc = await _firestore
              .collection('posts')
              .doc(postId)
              .collection('comments')
              .doc(commentId)
              .get();
          if (!commentDoc.exists) continue;
          final comment = Comment.fromJson({
            'id': commentDoc.id,
            'postId': postId,
            ..._normalizeFirestoreMap(commentDoc.data()!),
          });
          if (comment.postType != boardType) continue;
          activities.add(
            _commentToActivity(
              comment,
              activityType,
              createdAtOverride: _parseDateTime(likeData['createdAt']),
            ),
          );
        }

        if (snap.docs.isNotEmpty) {
          nextCursor = _makeCursor(
            snap.docs.last,
            fieldName: 'createdAt',
          );
        }
        hasMore = snap.docs.length == limit;
      } else if (activityType == 'scraped') {
        final query = _firestore
            .collection('users')
            .doc(userId)
            .collection('scraps')
            .orderBy('createdAt', descending: true)
            .limit(limit);

        final snap = await _applyCursor(
          query: query,
          cursor: startAfter,
          cursorField: 'createdAt',
        ).get();

        final postIds = snap.docs.map((doc) => doc.id).toList();
        if (postIds.isNotEmpty) {
          final posts = await _fetchPostsByIds(postIds);
          final postMap = {for (final post in posts) post.id: post};
          for (final id in postIds) {
            final post = postMap[id];
            if (post == null || post.postType != boardType) continue;
            activities.add(_postToActivity(post, activityType));
          }
        }

        if (snap.docs.isNotEmpty) {
          nextCursor = _makeCursor(
            snap.docs.last,
            fieldName: 'createdAt',
          );
        }
        hasMore = snap.docs.length == limit;
      }

      activities.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e, stackTrace) {
      AppLogger.e(
        'Error fetching activities: $e\n$stackTrace',
        error: e,
        stackTrace: stackTrace,
      );
    }

    return ActivityPage(
      items: activities,
      hasMore: hasMore,
      nextCursor: nextCursor,
    );
  }

  Query<Map<String, dynamic>> _applyCursor({
    required Query<Map<String, dynamic>> query,
    required ActivityCursor? cursor,
    required String cursorField,
  }) {
    if (cursor == null) return query;
    final cursorValue = cursor.sortValue;
    final firestoreCursorValue = cursorField == 'createdAt' || cursorField == 'votedAt'
        ? Timestamp.fromDate(cursorValue)
        : cursorValue;
    return query.startAfter([firestoreCursorValue]);
  }

  ActivityCursor _makeCursor(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    required String fieldName,
  }) {
    final sortValue = _parseDateTime(doc.data()[fieldName]);
    return ActivityCursor(
      sortValue: sortValue,
      documentId: doc.id,
    );
  }

  ActivityModel _postToActivity(
    Post post,
    String activityType, {
    DateTime? createdAtOverride,
  }) {
    return ActivityModel(
      id: post.id,
      sourcePostId: post.id,
      title: post.title,
      content: post.content,
      createdAt: createdAtOverride ?? post.createdAt ?? DateTime.now(),
      boardType: post.postType,
      activityType: activityType,
      likeCount: post.likeCount,
      commentCount: post.commentCount,
      viewCount: post.viewCount,
    );
  }

  ActivityModel _commentToActivity(
    Comment comment,
    String activityType, {
    DateTime? createdAtOverride,
  }) {
    return ActivityModel(
      id: comment.id,
      sourcePostId: comment.postId,
      title: activityType == 'liked_comment' ? '좋아요한 댓글' : '댓글 작성',
      content: comment.content,
      createdAt: createdAtOverride ?? comment.createdAt ?? DateTime.now(),
      boardType: comment.postType,
      activityType: activityType,
      likeCount: comment.likeCount,
      commentCount: 0,
      viewCount: 0,
    );
  }

  Future<List<Post>> _fetchPostsByIds(List<String> postIds) async {
    final posts = <Post>[];
    for (final postId in postIds) {
      final snapshot = await _firestore.collection('posts').doc(postId).get();
      if (!snapshot.exists) continue;
      posts.add(
        Post.fromJson({
          'id': snapshot.id,
          ..._normalizeFirestoreMap(snapshot.data()!),
        }),
      );
    }
    return posts;
  }

  Future<_FallbackPostDocsPage>
      _fetchFallbackPostDocs({
    required String userId,
    required String boardType,
    required int limit,
    required ActivityCursor? startAfter,
  }) async {
    final snapshot = await _firestore
        .collection('posts')
        .where('authorId', isEqualTo: userId)
        .where('postType', isEqualTo: boardType)
        .get();

    final docs = snapshot.docs.toList()
      ..sort((left, right) {
        final leftData = _normalizeFirestoreMap(left.data());
        final rightData = _normalizeFirestoreMap(right.data());
        final leftCreatedAt = _parseDateTime(leftData['createdAt']);
        final rightCreatedAt = _parseDateTime(rightData['createdAt']);
        final timeCompare = rightCreatedAt.compareTo(leftCreatedAt);
        if (timeCompare != 0) return timeCompare;
        return right.id.compareTo(left.id);
      });

    final filtered = startAfter == null
        ? docs
        : docs.where((doc) {
            final data = _normalizeFirestoreMap(doc.data());
            final createdAt = _parseDateTime(data['createdAt']);
            if (createdAt.isBefore(startAfter.sortValue)) {
              return true;
            }
            if (createdAt.isAtSameMomentAs(startAfter.sortValue)) {
              return doc.id.compareTo(startAfter.documentId) < 0;
            }
            return false;
          }).toList();

    final pageDocs = filtered.take(limit).toList();
    return _FallbackPostDocsPage(
      docs: pageDocs,
      hasMore: filtered.length > limit,
    );
  }

  DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Map<String, dynamic> _normalizeFirestoreMap(Map<String, dynamic> data) {
    return data.map((key, value) => MapEntry(key, _normalizeFirestoreValue(value)));
  }

  dynamic _normalizeFirestoreValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is Map<String, dynamic>) {
      return _normalizeFirestoreMap(value);
    }
    if (value is List) {
      return value.map(_normalizeFirestoreValue).toList();
    }
    return value;
  }
}

class _FallbackPostDocsPage {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final bool hasMore;

  const _FallbackPostDocsPage({
    required this.docs,
    required this.hasMore,
  });
}
