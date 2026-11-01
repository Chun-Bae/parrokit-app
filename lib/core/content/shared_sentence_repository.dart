import 'package:cloud_firestore/cloud_firestore.dart';

/// 둘러보기에 공개된 문장. 내가 등록한 문장을 공유하면 서버에 이 모양으로 올라간다.
class SharedSentence {
  const SharedSentence({
    required this.id,
    required this.language,
    required this.text,
    required this.translation,
    required this.pronunciation,
    required this.topic,
    required this.authorId,
    required this.authorName,
    required this.likeCount,
    this.liked = false,
    this.createdAt,
  });

  final String id;
  final String language;
  final String text;
  final String translation;
  final String pronunciation;
  final String topic;

  /// 작성자 uid와 공유 시점의 닉네임. 삭제·차단·"내가 올린 것" 판별은 uid로 한다.
  final String authorId;
  final String authorName;
  final int likeCount;

  /// 지금 보는 사람이 좋아요를 눌렀는지.
  final bool liked;
  final DateTime? createdAt;

  SharedSentence copyWith({int? likeCount, bool? liked}) => SharedSentence(
        id: id,
        language: language,
        text: text,
        translation: translation,
        pronunciation: pronunciation,
        topic: topic,
        authorId: authorId,
        authorName: authorName,
        likeCount: likeCount ?? this.likeCount,
        liked: liked ?? this.liked,
        createdAt: createdAt,
      );
}

/// 둘러보기 공개 문장의 저장소. 화면은 이 인터페이스만 본다.
abstract class SharedSentenceRepository {
  /// 최신순으로 [language] 문장을 가져온다. [viewerId]의 좋아요 여부도 함께 채운다.
  Future<List<SharedSentence>> list({
    required String language,
    required String viewerId,
    int limit = 30,
  });

  /// 내 문장을 공개한다. 이미 공개돼 있으면 내용만 갱신하고 좋아요는 유지한다.
  Future<void> publish({
    required String localSentenceId,
    required String authorId,
    required String authorName,
    required String language,
    required String text,
    required String translation,
    required String pronunciation,
    required String topic,
  });

  /// 공개를 취소한다. 공개돼 있지 않으면 아무것도 하지 않는다.
  Future<void> unpublish({
    required String authorId,
    required String localSentenceId,
  });

  Future<bool> isPublished({
    required String authorId,
    required String localSentenceId,
  });

  /// 좋아요를 켜거나 끈다. 이미 그 상태면 개수를 바꾸지 않는다.
  Future<void> setLiked({
    required String sharedId,
    required String viewerId,
    required bool liked,
  });
}

class FirestoreSharedSentenceRepository implements SharedSentenceRepository {
  FirestoreSharedSentenceRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const _fetchLimit = 200;

  /// 같은 사람이 같은 문장을 다시 공유해도 문서가 하나만 생기게 id를 정한다.
  static String idFor(String authorId, String localSentenceId) =>
      '$authorId:$localSentenceId';

  CollectionReference<Map<String, dynamic>> get _shared =>
      _firestore.collection('shared_sentences');

  DocumentReference<Map<String, dynamic>> _like(
    String viewerId,
    String sharedId,
  ) =>
      _firestore
          .collection('users')
          .doc(viewerId)
          .collection('sentence_likes')
          .doc(sharedId);

  @override
  Future<List<SharedSentence>> list({
    required String language,
    required String viewerId,
    int limit = 30,
  }) async {
    // 언어 하나만 조건으로 걸어 별도 복합 인덱스 없이 읽고, 최신순 정렬은 앱에서 한다.
    // 공유 문장이 아주 많아지면 createdAt 인덱스를 만들어 서버에서 정렬하는 쪽으로 바꾼다.
    final snapshot = await _shared
        .where('language', isEqualTo: language)
        .limit(_fetchLimit)
        .get();
    final likedIds = await _likedIds(viewerId);
    final items = [
      for (final doc in snapshot.docs)
        _fromDoc(doc.id, doc.data(), liked: likedIds.contains(doc.id)),
    ]..sort((a, b) {
        final left = a.createdAt, right = b.createdAt;
        if (left == null && right == null) return 0;
        // 방금 올려 서버 시각이 아직 없는 문장은 가장 위에 둔다.
        if (left == null) return -1;
        if (right == null) return 1;
        return right.compareTo(left);
      });
    return items.take(limit).toList(growable: false);
  }

  Future<Set<String>> _likedIds(String viewerId) async {
    if (viewerId.isEmpty) return {};
    final snapshot = await _firestore
        .collection('users')
        .doc(viewerId)
        .collection('sentence_likes')
        .get();
    return {for (final doc in snapshot.docs) doc.id};
  }

  SharedSentence _fromDoc(
    String id,
    Map<String, dynamic> data, {
    required bool liked,
  }) =>
      SharedSentence(
        id: id,
        language: data['language'] as String? ?? '',
        text: data['text'] as String? ?? '',
        translation: data['translation'] as String? ?? '',
        pronunciation: data['pronunciation'] as String? ?? '',
        topic: data['topic'] as String? ?? '내 문장',
        authorId: data['authorId'] as String? ?? '',
        authorName: data['authorName'] as String? ?? '',
        likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
        liked: liked,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      );

  @override
  Future<void> publish({
    required String localSentenceId,
    required String authorId,
    required String authorName,
    required String language,
    required String text,
    required String translation,
    required String pronunciation,
    required String topic,
  }) async {
    final doc = _shared.doc(idFor(authorId, localSentenceId));
    final existing = await doc.get();
    final content = {
      'language': language,
      'text': text,
      'translation': translation,
      'pronunciation': pronunciation,
      'topic': topic,
      'authorId': authorId,
      'authorName': authorName,
    };
    if (existing.exists) {
      await doc.update(content);
    } else {
      await doc.set({
        ...content,
        'likeCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Future<void> unpublish({
    required String authorId,
    required String localSentenceId,
  }) =>
      _shared.doc(idFor(authorId, localSentenceId)).delete();

  @override
  Future<bool> isPublished({
    required String authorId,
    required String localSentenceId,
  }) async =>
      (await _shared.doc(idFor(authorId, localSentenceId)).get()).exists;

  @override
  Future<void> setLiked({
    required String sharedId,
    required String viewerId,
    required bool liked,
  }) =>
      _firestore.runTransaction((tx) async {
        final likeRef = _like(viewerId, sharedId);
        final sharedRef = _shared.doc(sharedId);
        final current = (await tx.get(likeRef)).exists;
        if (current == liked) return;
        if (liked) {
          tx.set(likeRef, {'at': FieldValue.serverTimestamp()});
        } else {
          tx.delete(likeRef);
        }
        tx.update(
            sharedRef, {'likeCount': FieldValue.increment(liked ? 1 : -1)});
      });
}
