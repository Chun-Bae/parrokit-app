import 'package:cloud_firestore/cloud_firestore.dart';

import 'my_word_store.dart';

/// 로그인한 사용자의 단어를 Firestore `words`에 둔다. 본인만 읽고 쓴다
/// (firestore.rules의 match /words). 규칙이 배포되기 전에는 저장이
/// permission-denied로 실패하고, MyWordStore가 이 기기에 남긴다.
class FirestoreWordCloud implements WordCloud {
  FirestoreWordCloud({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const collection = 'words';

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _words =>
      _firestore.collection(collection);

  @override
  Future<List<MyWord>> load(String ownerId) async {
    final snapshot = await _words.where('ownerId', isEqualTo: ownerId).get();
    return [
      for (final doc in snapshot.docs)
        MyWord(
          id: doc.id,
          language: doc.data()['language'] as String? ?? '',
          word: doc.data()['word'] as String? ?? '',
          meaning: doc.data()['meaning'] as String? ?? '',
          example: doc.data()['example'] as String? ?? '',
          exampleTranslation:
              doc.data()['exampleTranslation'] as String? ?? '',
          sourceSentenceId: doc.data()['sourceSentenceId'] as String? ?? '',
          topic: doc.data()['topic'] as String? ?? '내 단어',
          addedAt: (doc.data()['createdAt'] as Timestamp?)?.toDate() ??
              DateTime.now(),
        ),
    ];
  }

  @override
  Future<bool> add(String ownerId, MyWord word) async {
    final same = await _words
        .where('ownerId', isEqualTo: ownerId)
        .where('language', isEqualTo: word.language)
        .get();
    final normalized = word.word.trim().toLowerCase();
    if (same.docs.any((d) =>
        (d.data()['word'] as String? ?? '').trim().toLowerCase() ==
        normalized)) {
      return false;
    }
    await _words.doc().set({
      'ownerId': ownerId,
      'language': word.language,
      'word': word.word,
      'meaning': word.meaning,
      'example': word.example,
      'exampleTranslation': word.exampleTranslation,
      'sourceSentenceId': word.sourceSentenceId,
      'topic': word.topic,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return true;
  }

  @override
  Future<void> remove(String id) => _words.doc(id).delete();
}
