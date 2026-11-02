import 'package:cloud_firestore/cloud_firestore.dart';

import 'default_conversation_sentences.dart';

/// 로그인한 사용자의 "내 문장"을 Firestore `sentences` 컬렉션에 보관한다.
///
/// 내 문장과 둘러보기에 공개된 문장은 같은 문서이고 `visibility`로만 구분한다.
/// - `ownerId`: 문서를 가진 사람. 읽기·수정·삭제 권한의 기준이다.
/// - `authorId`, `authorName`: 원작자. 내가 만든 문장이면 나, 남의 문장을 저장한 사본이면 원작자.
/// - `sourceSharedId`: 남의 공개 문장을 저장한 사본이면 원본 문서 id.
/// - `visibility`: `private`이면 나만, `public`이면 둘러보기에 보인다.
///   `public`은 `ownerId == authorId`일 때만 가능하다(보안 규칙이 강제한다).
class SentenceCloudStore {
  SentenceCloudStore({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const collection = 'sentences';
  static const private = 'private';
  static const public = 'public';

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _sentences =>
      _firestore.collection(collection);

  /// 내 문장을 오래된 순으로 돌려준다.
  Future<List<DefaultConversationSentence>> load(String ownerId) async {
    final snapshot =
        await _sentences.where('ownerId', isEqualTo: ownerId).get();
    return [
      for (final doc in snapshot.docs) _fromDoc(doc.id, doc.data()),
    ]..sort((a, b) => a.addedAt!.compareTo(b.addedAt!));
  }

  /// 같은 언어에 같은 문장이 이미 있으면 추가하지 않고 false를 돌려준다.
  Future<bool> add(
    String ownerId, {
    required String language,
    required String text,
    String translation = '',
    String pronunciation = '',
    String topic = '내 문장',
    String author = '',
    String authorId = '',
    String sourceSharedId = '',
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    final sameLanguage = await _sentences
        .where('ownerId', isEqualTo: ownerId)
        .where('language', isEqualTo: language)
        .get();
    final duplicated = sameLanguage.docs
        .any((doc) => (doc.data()['text'] as String? ?? '').trim() == trimmed);
    if (duplicated) return false;
    // 앱이 문장 id를 "my-"로 시작하는 것으로 내 문장임을 알아본다.
    final id = 'my-${_sentences.doc().id}';
    await _sentences.doc(id).set({
      'ownerId': ownerId,
      'authorId': authorId.isNotEmpty ? authorId : ownerId,
      'authorName': author.trim(),
      'language': language,
      'text': trimmed,
      'translation': translation.trim(),
      'pronunciation': pronunciation.trim(),
      'topic': topic,
      'visibility': private,
      'likeCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      if (sourceSharedId.isNotEmpty) 'sourceSharedId': sourceSharedId,
    });
    return true;
  }

  Future<void> remove(String id) => _sentences.doc(id).delete();

  DefaultConversationSentence _fromDoc(String id, Map<String, dynamic> data) =>
      DefaultConversationSentence(
        id: id,
        language: data['language'] as String? ?? '',
        text: data['text'] as String? ?? '',
        translation: data['translation'] as String? ?? '',
        pronunciation: data['pronunciation'] as String? ?? '',
        topic: data['topic'] as String? ?? '내 문장',
        author: data['authorName'] as String? ?? '',
        authorId: data['authorId'] as String? ?? '',
        sourceSharedId: data['sourceSharedId'] as String? ?? '',
        // 방금 만들어 서버 시각이 아직 없으면 지금으로 본다.
        addedAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
}
