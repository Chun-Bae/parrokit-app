import 'package:cloud_firestore/cloud_firestore.dart';

/// 테스트용으로 `sentences` 문서 하나를 넣는다. 서버에 올라간 내 문장이나 남의 공개 문장을 흉내 낸다.
Future<void> seedSentence(
  FirebaseFirestore firestore,
  String id, {
  String ownerId = 'u1',
  String? authorId,
  String authorName = '앵무',
  String language = '영어',
  String text = 'Hello there',
  String translation = '안녕',
  String pronunciation = '',
  String topic = '내 문장',
  String visibility = 'private',
  int likeCount = 0,
  String sourceSharedId = '',
  DateTime? createdAt,
}) =>
    firestore.collection('sentences').doc(id).set({
      'ownerId': ownerId,
      'authorId': authorId ?? ownerId,
      'authorName': authorName,
      'language': language,
      'text': text,
      'translation': translation,
      'pronunciation': pronunciation,
      'topic': topic,
      'visibility': visibility,
      'likeCount': likeCount,
      'createdAt': Timestamp.fromDate(createdAt ?? DateTime.now()),
      if (sourceSharedId.isNotEmpty) 'sourceSharedId': sourceSharedId,
    });
