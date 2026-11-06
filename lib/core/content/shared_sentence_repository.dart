import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'sentence_cloud_store.dart';

/// 하루 공유 한도를 넘겨서 공개하지 못했을 때 던진다.
class ShareLimitReachedException implements Exception {
  const ShareLimitReachedException();

  @override
  String toString() =>
      '하루에 ${SharedSentenceRepository.dailyShareLimit}개까지 공유할 수 있어요.';
}

/// 둘러보기에 공개된 문장. 내 문장(`sentences` 문서)의 `visibility`가 `public`이면 이 모양으로 보인다.
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
    this.importCount = 0,
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

  /// 이 문장을 내 문장으로 가져간 사람 수. 사람마다 한 번만 센다.
  final int importCount;

  /// 지금 보는 사람이 좋아요를 눌렀는지.
  final bool liked;
  final DateTime? createdAt;

  SharedSentence copyWith({int? likeCount, int? importCount, bool? liked}) =>
      SharedSentence(
        id: id,
        language: language,
        text: text,
        translation: translation,
        pronunciation: pronunciation,
        topic: topic,
        authorId: authorId,
        authorName: authorName,
        likeCount: likeCount ?? this.likeCount,
        importCount: importCount ?? this.importCount,
        liked: liked ?? this.liked,
        createdAt: createdAt,
      );
}

/// 둘러보기 공개 문장의 저장소. 화면은 이 인터페이스만 본다.
abstract class SharedSentenceRepository {
  /// 한 사람이 하루에 새로 공개할 수 있는 문장 수. 하루는 한국 시간 0시에 바뀐다.
  /// 같은 한도가 firestore.rules에도 있다.
  static const dailyShareLimit = 10;

  /// 공개 목록이 바뀔 수 있는 일(공개·공개 취소·공개한 문장 삭제)이 있으면 올라간다.
  /// 둘러보기 화면이 이 값을 보고 목록을 다시 읽는다.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// 최신순으로 [language] 문장을 가져온다. [viewerId]의 좋아요 여부도 함께 채운다.
  Future<List<SharedSentence>> list({
    required String language,
    required String viewerId,
    int limit = 30,
  });

  /// 내 문장을 둘러보기에 공개한다. 이미 공개돼 있으면 작성자 닉네임만 갱신한다.
  /// 새로 공개할 때는 하루 한도([dailyShareLimit])를 쓰고, 넘으면 [ShareLimitReachedException]을 던진다.
  /// 공개를 취소했다가 다시 공개해도 한도를 다시 쓴다.
  /// [sentenceId]는 내 문장 문서의 id이고, 남의 문장을 저장한 사본은 공개할 수 없다.
  Future<void> publish({
    required String sentenceId,
    required String authorName,
  });

  /// 공개를 취소한다(문장은 내 문장함에 남는다). 공개돼 있지 않으면 아무것도 하지 않는다.
  Future<void> unpublish({required String sentenceId});

  Future<bool> isPublished({required String sentenceId});

  /// [viewerId]가 이 문장을 내 문장으로 가져갔다고 세어 둔다.
  /// 같은 사람이 다시 가져가거나 내가 쓴 문장이면 세지 않고 false를 돌려준다.
  Future<bool> recordImport({
    required String sharedId,
    required String viewerId,
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

  CollectionReference<Map<String, dynamic>> get _shared =>
      _firestore.collection(SentenceCloudStore.collection);

  DocumentReference<Map<String, dynamic>> _like(
    String viewerId,
    String sharedId,
  ) =>
      _firestore
          .collection('users')
          .doc(viewerId)
          .collection('sentence_likes')
          .doc(sharedId);

  DocumentReference<Map<String, dynamic>> _import(
    String viewerId,
    String sharedId,
  ) =>
      _firestore
          .collection('users')
          .doc(viewerId)
          .collection('sentence_imports')
          .doc(sharedId);

  @override
  Future<List<SharedSentence>> list({
    required String language,
    required String viewerId,
    int limit = 30,
  }) async {
    // 공개 여부와 언어를 같음 조건으로만 걸어 별도 복합 인덱스 없이 읽고, 최신순 정렬은 앱에서 한다.
    // 공유 문장이 아주 많아지면 createdAt 인덱스를 만들어 서버에서 정렬하는 쪽으로 바꾼다.
    final snapshot = await _shared
        .where('visibility', isEqualTo: SentenceCloudStore.public)
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
        importCount: (data['importCount'] as num?)?.toInt() ?? 0,
        liked: liked,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      );

  /// 오늘 공유 횟수를 세는 문서. 문서 id는 한국 시간 기준 날짜이고 firestore.rules가 같은 값을 검사한다.
  DocumentReference<Map<String, dynamic>> _quota(String ownerId, DateTime now) {
    final kst = now.toUtc().add(const Duration(hours: 9));
    return _firestore
        .collection('users')
        .doc(ownerId)
        .collection('share_quota')
        .doc('${kst.year}-${kst.month}-${kst.day}');
  }

  @override
  Future<void> publish({
    required String sentenceId,
    required String authorName,
  }) =>
      _firestore.runTransaction((tx) async {
        final ref = _shared.doc(sentenceId);
        final data = (await tx.get(ref)).data();
        if (data == null) throw StateError('sentence not found');
        if (data['visibility'] == SentenceCloudStore.public) {
          // 이미 공개돼 있으면 한도를 쓰지 않고 닉네임만 갱신한다.
          tx.update(ref, {'authorName': authorName});
          return;
        }
        final quotaRef = _quota(data['ownerId'] as String, DateTime.now());
        final used =
            ((await tx.get(quotaRef)).data()?['count'] as num?)?.toInt() ?? 0;
        if (used >= SharedSentenceRepository.dailyShareLimit) {
          throw const ShareLimitReachedException();
        }
        tx.set(quotaRef, {'count': used + 1});
        tx.update(ref, {
          'visibility': SentenceCloudStore.public,
          'authorName': authorName,
        });
      }).then((_) => SharedSentenceRepository.revision.value++);

  @override
  Future<void> unpublish({required String sentenceId}) async {
    await _shared
        .doc(sentenceId)
        .update({'visibility': SentenceCloudStore.private});
    SharedSentenceRepository.revision.value++;
  }

  @override
  Future<bool> isPublished({required String sentenceId}) async {
    final doc = await _shared.doc(sentenceId).get();
    return doc.data()?['visibility'] == SentenceCloudStore.public;
  }

  @override
  Future<bool> recordImport({
    required String sharedId,
    required String viewerId,
  }) =>
      _firestore.runTransaction((tx) async {
        final importRef = _import(viewerId, sharedId);
        final sharedRef = _shared.doc(sharedId);
        final shared = await tx.get(sharedRef);
        final data = shared.data();
        if (data == null || data['authorId'] == viewerId) return false;
        if ((await tx.get(importRef)).exists) return false;
        tx.set(importRef, {'at': FieldValue.serverTimestamp()});
        tx.update(sharedRef, {'importCount': FieldValue.increment(1)});
        return true;
      });

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
